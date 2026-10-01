# Deployer user bootstrap (least privilege)

This is a **separate, one-time-use Terraform root module** with its own state — it is not
part of the main `backend-infra` configuration one directory up. It creates:

- the legacy command-line deployer user;
- the GitHub Actions OIDC provider and a production deployment role;
- the least-privilege deployment policy used by both deployment identities;
- a dedicated Supabase project and Postgres database to hold the main configuration's
  Terraform state.

The GitHub role can be assumed only by the configured repository's `production` environment.
The main configuration stores its own state directly in a Postgres database inside the project
created here (Terraform's `pg` backend), rather than as a file.

## Why the Terraform-state project is separate

The main configuration creates the application's own Supabase project
(`supabase_project.catalogue`). Terraform needs somewhere to store state *before* it can create
anything, so the state database cannot live inside the project the main configuration is about
to create — it needs a project that already exists. This module creates that project for you,
and outputs a ready-to-use connection string — no further manual setup is needed.

## Why you still need existing credentials once

Terraform cannot create IAM credentials out of nothing. Running `terraform apply` here at all
still requires *some* existing AWS credentials with enough IAM permission to create a user,
policy, and access key — for example, your account's root user (fine once, but switch away
from it immediately afterwards), or an existing IAM identity with `iam:CreateUser`,
`iam:CreatePolicy`, `iam:CreateAccessKey`, and `iam:AttachUserPolicy` (an `IAMFullAccess` or
`AdministratorAccess` user works). Use those broader credentials **only for this one bootstrap
step**, then switch to the generated deployer user for everything else, including every future
run of the main `backend-infra` configuration.

## Usage

Export a Supabase personal access token first (sensitive; never put a real token in
`terraform.tfvars`):

```sh
export TF_VAR_supabase_access_token='<Supabase personal access token>'
```

```sh
cd backend-infra/bootstrap
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars and set supabase_organization_id to your org slug
terraform init
terraform apply
```

Override `github_repository` or `github_environment` only when the workflow location or
protected environment name differs from the defaults. Override `tfstate_project_name` or
`supabase_region` only if you want the Terraform-state project named or located differently.

Retrieve the generated credentials (the secret is marked `sensitive`, so it never appears in
the normal `apply` output):

```sh
terraform output deployer_access_key_id
terraform output -raw deployer_secret_access_key
terraform output -raw tfstate_database_url
```

Use `tfstate_database_url` directly as `SUPABASE_TFSTATE_DATABASE_URL` in the main
`backend-infra/README.md`'s "State security" section — the connection string already points at
the Postgres database created above, with no manual bucket or access-key setup required.

Configure a dedicated AWS CLI profile for the deployer user rather than overwriting your
existing default profile:

```sh
aws configure --profile tango-deployer
# paste the access key id / secret access key from the outputs above; region eu-west-2
export AWS_PROFILE=tango-deployer
```

Verify it works and check the identity it reports:

```sh
aws sts get-caller-identity --profile tango-deployer
```

Configure the bootstrap outputs as variables on the GitHub `production` environment:

```sh
terraform output github_actions_role_arn
```

Use this value for `AWS_ROLE_ARN`. Use `terraform output -raw tfstate_database_url` for
`SUPABASE_TFSTATE_DATABASE_URL` — no further manual steps are needed to make it usable.

From now on, run every command in the main `backend-infra/README.md` (its `terraform
init`/`plan`/`apply`) with `AWS_PROFILE=tango-deployer` set, instead of whatever broader
credentials you used for this bootstrap step.

## What this user can and cannot do

The attached policy (see `main.tf`) only allows:

- Managing IAM roles/policies named `tango-music-game-*` (the Lambda execution roles), and
  passing those roles only to `lambda.amazonaws.com`.
- Creating/updating/deleting Lambda functions named `tango-music-game-*`.
- Managing CloudWatch log groups under `/aws/lambda/tango-music-game-*` (the log-group
  *listing* action is necessarily account-wide and read-only, since AWS does not support
  scoping `logs:DescribeLogGroups` by name).
- Managing SSM parameters under `/tango-music-game/*`.
- Managing API Gateway v2 APIs, routes, integrations, and stages (API Gateway does not support
  scoping by API name at the IAM level — only by service and region, since API IDs are
  assigned at creation time).
- Reading its own caller identity (`sts:GetCallerIdentity`).

It **cannot** create or modify any other IAM user, role, or policy; touch any other AWS
service; or touch any resource outside the `tango-music-game` naming prefix. It also has no
Supabase permissions of any kind — the Supabase Terraform provider authenticates separately via
`TF_VAR_supabase_access_token` (see the main `backend-infra/README.md`), which this AWS user has
no bearing on.

If you rename resources in the main configuration (a different `resource_name_prefix`, a new
AWS service, etc.), update `main.tf` here to match, or the deployer user's permissions will be
out of date and `terraform apply` in the main configuration will fail with an access-denied
error.

## Rotating or removing the deployer user

Rotate the access key periodically:

```sh
terraform taint aws_iam_access_key.deployer
terraform apply
```

Update your `tango-deployer` AWS CLI profile with the new key pair afterwards.

To remove the deployer user entirely (e.g. tearing down the whole project), run `terraform
destroy` here only after the main `backend-infra` configuration no longer needs it — you cannot
apply changes there with a user that no longer exists.

## Rotating the Terraform-state database password

```sh
terraform taint random_password.tfstate_database
terraform apply
```

This generates a new password and updates it on the Supabase project in one step. Re-fetch the
connection string afterwards and update `SUPABASE_TFSTATE_DATABASE_URL` everywhere it is
configured (local shell, GitHub environment secret):

```sh
terraform output -raw tfstate_database_url
```
