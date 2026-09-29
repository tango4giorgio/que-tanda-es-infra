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
export TF_VAR_supabase_access_token='<Supabase personal access token>'
export TF_VAR_supabase_database_password='<strong database password>'
```

To get a Supabase personal access token: sign in to the
[Supabase dashboard](https://supabase.com/dashboard), go to
**Account → Access Tokens → Generate new token**, and copy it immediately (it is only shown
once). Treat it like a password — never commit it or put it directly in `terraform.tfvars`.

Choose `TF_VAR_supabase_database_password` yourself (at least 12 characters, per the
variable's validation rule); this becomes the initial password for the Supabase Postgres
database that Terraform creates.

Set `supabase_organization_id` in `terraform.tfvars` to the organisation slug shown in the
Supabase dashboard (**Organisation Settings → General → Slug**, not the display name).
`lambda_reserved_concurrency` defaults to `5` and must remain within the
validated range of 1–20 unless the Supabase connection budget is deliberately redesigned.

## State security

Terraform state contains the Supabase database password and generated connection URL even
though CLI output marks them sensitive. For any shared environment:

- use the encrypted S3 backend and DynamoDB locking created by the bootstrap module;
- grant state access only to infrastructure maintainers and deployment identities;
- never commit state, plans, variable files, or copied secret output;
- keep `prevent_destroy` on the Supabase project.

For local commands, initialise the same remote backend used by GitHub Actions:

```sh
terraform init \
  -backend-config="bucket=<state-bucket>" \
  -backend-config="key=backend-infra/terraform.tfstate" \
  -backend-config="region=eu-west-2" \
  -backend-config="dynamodb_table=<lock-table>" \
  -backend-config="encrypt=true"
```

## Existing Supabase project

Import an existing project rather than recreating it:

```sh
terraform import supabase_project.catalogue '<project-ref>'
terraform plan
```

Review and resolve imported drift before applying.

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

## GitHub Actions deployment

The `Deploy infrastructure` workflow performs a manual production deployment using a backend
release tag supplied when the workflow is started. It authenticates to AWS using GitHub OIDC,
uses the shared S3 state backend with DynamoDB locking, checks formatting, validates the
configuration, creates a saved plan, and applies that exact plan.

Create a GitHub environment named `production`, add any required reviewers, and configure:

| Type | Name | Value |
| --- | --- | --- |
| Environment variable | `AWS_ROLE_ARN` | `github_actions_role_arn` from the bootstrap outputs |
| Environment variable | `TF_STATE_BUCKET` | `terraform_state_bucket_name` from the bootstrap outputs |
| Environment variable | `TF_LOCK_TABLE` | `terraform_lock_table_name` from the bootstrap outputs |
| Environment variable | `SUPABASE_ORGANIZATION_ID` | Supabase organisation slug |
| Environment secret | `SUPABASE_ACCESS_TOKEN` | Supabase personal access token |
| Environment secret | `SUPABASE_DATABASE_PASSWORD` | Supabase database password |

Run the bootstrap module once before the first deployment, then open **Actions**, choose
**Deploy infrastructure**, select **Run workflow**, and enter a published backend release tag.

After the Supabase project is ready, apply the migrations and load provider links from the
parent directory:

```sh
export DATABASE_URL="$(terraform -chdir=backend-infra output -raw supabase_database_url)"
psql "$DATABASE_URL" -f backend/src/migrations/0001_create_catalogue_schema.sql
psql "$DATABASE_URL" -f backend/src/migrations/0002_create_musicbrainz_recording_cache.sql
psql "$DATABASE_URL" -f backend/src/migrations/0003_create_feedback_schema.sql
PYTHONPATH=backend python3 backend/scripts/load_provider_links.py \
  --source recording-provider-links.json
```

The Lambda uses the Supabase shared transaction pooler on port 6543. The current connection
string uses encrypted transport with `sslmode=require`; move to `sslmode=verify-full` when the
Supabase CA certificate is packaged and supplied consistently to local and Lambda runtimes.

The plan must show reverse-proxy gateway routes for `GET /game`, `POST /previews`, and
`POST /feedback`, a scoped secret-read policy per Lambda, bounded Lambda concurrency, the
protected Supabase project, and the transaction-pooler connection output. No MusicBrainz
refresh worker is deployed by Terraform.
