# Tango Music Game Backend Infrastructure

Terraform for the catalogue backend's Supabase and AWS resources.

This folder is intentionally separate from `backend/` so it can later become an independent
infrastructure repository. It consumes the Lambda deployment package produced by the backend
at `../backend/dist/get_catalogue.zip`.

## Resources

- Protected Supabase project (`prevent_destroy = true`)
- Supabase SSL enforcement and PostgREST settings
- AWS Secrets Manager database connection secret
- Python 3.12 ARM64 Lambda
- API Gateway HTTP API exposing `GET /catalogue`
- Lambda IAM and invocation permissions

The Supabase organisation must already exist. The official Terraform provider creates projects
inside an organisation but does not create organisations.

## Configure

```sh
cp terraform.tfvars.example terraform.tfvars
export TF_VAR_supabase_access_token='<Supabase personal access token>'
export TF_VAR_supabase_database_password='<strong database password>'
```

Set `supabase_organization_id` in `terraform.tfvars` to the organisation slug shown in the
Supabase dashboard.

## Validate and apply

Build the Lambda package in `backend/dist/get_catalogue.zip` before planning:

```sh
terraform init
terraform fmt -check
terraform validate
terraform plan
terraform apply
```

After the Supabase project is ready, apply the application-owned migrations and load data from
the repository root:

```sh
export DATABASE_URL="$(terraform -chdir=backend-infra output -raw supabase_database_url)"

psql "$DATABASE_URL" -f backend/src/migrations/0001_create_music_schema.sql
psql "$DATABASE_URL" -f backend/src/migrations/0002_create_catalogue_schema.sql

PYTHONPATH=backend python3 backend/scripts/load_starter_catalogue.py \
  --source frontend/public/catalogue/starter-catalogue.json
```

The database password and generated connection URL are stored in Terraform state. Configure an
encrypted remote state backend before using this stack outside local development.
