# Tango Music Game Backend Infrastructure

Terraform for the tango music game's Supabase and AWS resources. This repository consumes the
immutable Lambda packages built from the sibling `backend/` repository: complete-game
generation, batched preview resolution, anonymous feedback, and the reverse-proxy gateway.

## Resources

- Protected Supabase project with `prevent_destroy`
- Supabase SSL enforcement and private application schema settings
- AWS SSM Parameter Store `SecureString` for the transaction-pooler connection string (free
  Standard tier, no customer-managed KMS key)
- Python 3.12 ARM64 Lambdas (game generation, preview resolution, anonymous feedback
  submission, and the reverse-proxy gateway) with bounded reserved concurrency
- CloudWatch log groups with explicit retention (encrypted at rest by AWS-owned keys by
  default; no customer-managed KMS key, to avoid its flat $1/month/key charge)
- API Gateway HTTP API, fronted by the reverse-proxy gateway Lambda, exposing `GET /game`,
  `POST /previews`, and `POST /feedback`
- Least-privilege Lambda IAM and invocation permissions

The Supabase organisation must already exist. The provider creates projects inside an
organisation but does not create organisations.

## Prerequisites

Install these tools locally before doing anything else:

- **Terraform** `>= 1.6.0` — [install instructions](https://developer.hashicorp.com/terraform/install).
  Check with `terraform version`.
- **AWS CLI v2** — [install instructions](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html).
  Not strictly required by Terraform itself, but the easiest way to configure AWS credentials
  and to verify they work.
- **psql** (PostgreSQL client) — used later to apply database migrations.
- An **AWS account** with permission to create Lambda, API Gateway, IAM, CloudWatch Logs, and
  SSM Parameter Store resources.
- A **Supabase account** with an existing organisation (see the note above — Terraform cannot
  create the organisation itself, only projects inside one).

### AWS authentication

Terraform's `aws` provider (`providers.tf`) does not hardcode or configure credentials itself
— it relies on the AWS CLI/SDK's standard **default credential chain**, which is why this
README previously didn't mention it explicitly. Set up credentials using *one* of these
methods before running any `terraform` command:

1. **AWS CLI config (simplest for a beginner)**:

   ```sh
   aws configure
   ```

   This prompts for an **AWS Access Key ID**, **Secret Access Key**, default region (use
   `eu-west-2` to match this project's default), and output format, then stores them in
   `~/.aws/credentials` and `~/.aws/config`. Terraform will pick these up automatically with
   no extra configuration.

   To get an access key: sign in to the [AWS Console](https://console.aws.amazon.com/),
   go to **IAM → Users → your user → Security credentials → Create access key**. If you don't
   have an IAM user yet, create one with at least the permissions listed under Resources
   above (or `AdministratorAccess` while first getting this working, then narrow it down —
   or use the least-privilege bootstrap module described just below instead of widening an
   existing user's permissions).

2. **Environment variables** (useful for CI or temporary credentials):

   ```sh
   export AWS_ACCESS_KEY_ID='<your access key id>'
   export AWS_SECRET_ACCESS_KEY='<your secret access key>'
   export AWS_SESSION_TOKEN='<only if using temporary/STS credentials>'
   export AWS_REGION='eu-west-2'
   ```

3. **AWS SSO / named profile**, if your organisation uses it:

   ```sh
   aws sso login --profile my-profile
   export AWS_PROFILE=my-profile
   ```

   Some versions of the Terraform `aws` provider do not resolve SSO sessions from
   `AWS_PROFILE` alone and fail with a credential error even though `aws sts get-caller-identity
   --profile my-profile` succeeds. If that happens, export the resolved short-lived credentials
   as plain environment variables instead, using the AWS CLI's built-in credential exporter:

   ```sh
   eval "$(aws configure export-credentials --profile my-profile --format env)"
   ```

   This reads the active SSO session for `my-profile` and sets `AWS_ACCESS_KEY_ID`,
   `AWS_SECRET_ACCESS_KEY`, and `AWS_SESSION_TOKEN` in the current shell, which Terraform's
   default credential chain always understands regardless of provider version. Re-run this
   command whenever the SSO session expires (`aws sso login --profile my-profile` again first).

Verify your credentials work before touching Terraform:

```sh
aws sts get-caller-identity
```

### Creating a least-privilege deployer user instead of using your own

Rather than using a personal/admin AWS identity for every `terraform apply` below, you can use
Terraform itself to create a dedicated IAM user scoped to only the permissions this
configuration needs (Lambda, its IAM roles, API Gateway v2, CloudWatch Logs, and SSM Parameter
Store — no `AdministratorAccess`, no access to any other AWS service or resource). See
[`bootstrap/README.md`](bootstrap/README.md) for the one-time setup (it still needs *some*
existing credentials to create that user in the first place — Terraform cannot create
credentials from nothing).

This should print your AWS account ID and IAM user/role ARN. If it errors, fix your AWS
credentials first — every `terraform plan`/`apply` below will fail identically until this
succeeds.

## Configure

```sh
cp terraform.tfvars.example terraform.tfvars
export TF_VAR_app_runtime_password='<strong password>'
```

Set `supabase_project_ref` in `terraform.tfvars` to the reference produced by the one-off
`app-database/` configuration. The main infrastructure configuration does not use a Supabase
management token or database superuser password.

`TF_VAR_app_runtime_password` is the password assigned by the backend repository's one-off
database-bootstrap workflow. Terraform uses it only to build the transaction-pooler URL stored
in SSM for the Lambdas; it cannot run DDL.

`lambda_reserved_concurrency` defaults to `5` and must remain within the
validated range of 1–20 unless the Supabase connection budget is deliberately redesigned.

## State security

Terraform state contains the Supabase database password and generated connection URL even
though CLI output marks them sensitive. For any shared environment:

- use the dedicated Terraform-state Postgres database described below;
- grant its connection string only to infrastructure maintainers and the deployment identity;
- never commit state, plans, variable files, or copied secret output;
- keep `prevent_destroy` on the Supabase project.

Before initialising Terraform, run the `bootstrap/` module first if you have not already —
besides the AWS deployer user and GitHub Actions role, it also creates a dedicated Supabase
project and database to hold Terraform state (see `bootstrap/README.md`). It must be separate
from the application's own Supabase project because both the one-off `app-database/` root and
the main infrastructure root need their state backend before they can create any resources.

State is stored using Terraform's `pg` backend, which keeps state as rows in a Postgres table
rather than as a file, and uses Postgres advisory locks for real state locking — concurrent
`plan`/`apply` runs are safely serialised instead of silently racing. Retrieve the ready-to-use
connection string directly from the bootstrap module's output:

```sh
cd bootstrap && terraform output -raw tfstate_database_url && cd ..
```

The connection string uses the Supabase connection pooler in **session mode** (port `5432`),
not the transaction-mode pooler (port `6543`) used for the application's own runtime
connections — advisory locks do not survive transaction-mode pooling, so using the wrong mode
silently disables locking.

Set the connection string in your shell, then initialise:

```sh
export SUPABASE_TFSTATE_DATABASE_URL='<connection string from bootstrap output>'

cat > supabase.tfbackend <<EOF
conn_str = "$SUPABASE_TFSTATE_DATABASE_URL"
EOF

terraform init -backend-config=supabase.tfbackend
```

The generated `supabase.tfbackend` file contains credentials and is ignored to prevent an
accidental secret commit. The one-off application-database root uses the same connection with
a separate `application_database_state` schema.

## Lambda packages

The Lambda `.zip` packages (`get_game.zip`, `get_previews.zip`, `gateway.zip`, and
`submit_feedback.zip`) are
**not built locally**. They are built by the backend repo's own CI
(`.github/workflows/release.yml` in
[`que-tanda-es-backend`](https://github.com/tango4giorgio/que-tanda-es-backend)) and published
as assets on a tagged GitHub Release whenever a `v*` tag is pushed there.

Terraform downloads them at plan/apply time via the `data "external"` blocks in
`lambda_packages.tf`, which shell out to `scripts/fetch-lambda-package.sh`. That script:

- downloads `https://github.com/<backend_release_repo>/releases/download/<backend_release_tag>/<asset>.zip`;
- caches each asset under `.lambda-packages/<tag>/` so repeat plans for the same tag don't
  re-download;
- reports back the local path and a base64 SHA-256 digest, which Terraform uses as
  `source_code_hash` — so a new release tag (different content) is detected and redeploys the
  Lambda automatically, exactly like a locally-built zip would.

You must set **`backend_release_tag`** (no default — pinned deliberately, so deployments are
explicit and reviewable) to a tag that has already been released with all three assets
attached, e.g. in `terraform.tfvars`:

```hcl
backend_release_tag = "v0.2.0"
```

`backend_release_repo` defaults to `tango4giorgio/que-tanda-es-backend`; override it only if
you are deploying from a fork.

To release a new backend version: push a `v*` tag to the backend repo (`git tag v0.2.0 && git
push origin v0.2.0`), wait for its release workflow to publish the three assets, then bump
`backend_release_tag` here and re-apply.

## Validate and apply

With `backend_release_tag` set to a published release (see above), from `backend-infra/`:

```sh
terraform init
terraform fmt -check
terraform validate
terraform plan
terraform apply
```

## Deployment lifecycle

Database creation, database initialisation, and normal releases are deliberately separate:

1. Create or import the Supabase application project once.
2. Bootstrap the database roles and initial schema once.
3. For each release, apply outstanding migrations before publishing Lambda packages.
4. Deploy the published Lambda packages and AWS infrastructure.

### 1. Create the application database once

The `app-database/` Terraform root is the only configuration that receives the Supabase
management token and database superuser password. Create a GitHub environment named
`database-creation`, require an appropriate reviewer, and configure:

| Type | Name | Value |
| --- | --- | --- |
| Environment variable | `SUPABASE_ORGANIZATION_ID` | Supabase organisation slug |
| Environment secret | `SUPABASE_ACCESS_TOKEN` | Supabase personal access token |
| Environment secret | `SUPABASE_DATABASE_PASSWORD` | Initial database superuser password |
| Environment secret | `SUPABASE_TFSTATE_DATABASE_URL` | `tfstate_database_url` from the bootstrap outputs |

Open **Actions**, choose **Create application database**, and run the workflow. It writes the
new `SUPABASE_PROJECT_REF` value to the workflow summary. The state is isolated in the
`application_database_state` schema of the Terraform-state database.

If the project already exists, supply its 20-character reference as
`existing_project_ref`. Before the next main infrastructure apply, the `removed` blocks in
`supabase.tf` safely remove the old Supabase resources from the main state without destroying
them; the application-database workflow imports them into its own state.

After creation/import and verification, restrict or remove access to the `database-creation`
environment. Normal deployments do not use any of its secrets.

### 2. Bootstrap database roles and schema once

In the backend repository, create a separately protected GitHub environment named
`database-bootstrap` with:

| Type | Name | Value |
| --- | --- | --- |
| Environment secret | `SUPERUSER_DATABASE_URL` | `postgres.<project-ref>` session-pooler URL on port 5432 |
| Environment secret | `MIGRATION_DATABASE_URL` | `migration_runner.<project-ref>` session-pooler URL on port 5432 |
| Environment secret | `MIGRATION_RUNNER_PASSWORD` | Strong password used only for schema migrations |
| Environment secret | `APP_RUNTIME_PASSWORD` | Strong password used only by the deployed application |

Run **Bootstrap application database**. The workflow creates or reconciles the two roles,
transfers any existing public-schema objects to `migration_runner`, and applies outstanding
versioned migrations. It is idempotent, but should normally be needed only once.

Percent-encode passwords when constructing either PostgreSQL URL; the usernames are
`postgres.<project-ref>` and `migration_runner.<project-ref>`.

Once verified, remove `SUPERUSER_DATABASE_URL` or lock the environment. Release workflows
cannot access it.

### 3. Release backend packages

In the backend repository's `production` environment, configure only:

| Type | Name | Value |
| --- | --- | --- |
| Environment secret | `MIGRATION_DATABASE_URL` | `migration_runner.<project-ref>` session-pooler URL on port 5432 |

Pushing a `v*` tag first runs the checksum-backed migration runner. Lambda packages are built
and published only if every outstanding migration succeeds. The manual **Run database
migrations manually** workflow is retained for recovery.

Applied migrations are recorded in `public.schema_migration`. Editing an already-applied
migration causes a checksum failure rather than silently replaying changed SQL.

### 4. Deploy AWS infrastructure

The `Deploy infrastructure` workflow performs a manual production deployment using a backend
release tag supplied when the workflow is started. It authenticates to AWS using GitHub OIDC,
stores state in the dedicated Terraform-state Postgres database, checks formatting, validates
the configuration, creates a saved plan, and applies that exact plan locally in GitHub Actions.

Create a GitHub environment named `production`, add any required reviewers, and configure:

| Type | Name | Value |
| --- | --- | --- |
| Environment variable | `AWS_ROLE_ARN` | `github_actions_role_arn` from the bootstrap outputs |
| Environment variable | `SUPABASE_PROJECT_REF` | Output from the application-database workflow |
| Environment secret | `SUPABASE_TFSTATE_DATABASE_URL` | `tfstate_database_url` from the bootstrap outputs |
| Environment secret | `APP_RUNTIME_PASSWORD` | Password assigned during database bootstrap |

Run the bootstrap module once before the first deployment, then open **Actions**, choose
**Deploy infrastructure**, select **Run workflow**, and enter a published backend release tag.
This workflow manages AWS resources and the Lambda runtime connection only. It never receives
the Supabase management token, database superuser password, or migration credential.

The Lambda uses the Supabase shared transaction pooler on port 6543. The current connection
string uses encrypted transport with `sslmode=require`; move to `sslmode=verify-full` when the
Supabase CA certificate is packaged and supplied consistently to local and Lambda runtimes.

The plan must show reverse-proxy gateway routes for `GET /game`, `POST /previews`, and
`POST /feedback`, a scoped secret-read policy per Lambda, bounded Lambda concurrency, the
protected Supabase project, and the transaction-pooler connection output. No MusicBrainz
refresh worker is deployed by Terraform.
