# Application Database

One-off Terraform root for creating or importing the Supabase project and managing its
`migration_runner` and `app_runtime` roles and grants. Normal infrastructure deployments do not
run this configuration and do not receive its Supabase management token or database superuser
password.

The role SQL is compatible with Supabase's managed `postgres` role, which has administrative
privileges but is not a true PostgreSQL superuser. It does not attempt to alter superuser or
replication attributes.

Prefer the **Create application database** GitHub Actions workflow documented in the repository
README. For local use:

```sh
cp terraform.tfvars.example terraform.tfvars
export TF_VAR_supabase_access_token='<Supabase personal access token>'
export TF_VAR_supabase_database_password='<strong superuser password>'
export TF_VAR_migration_runner_password='<strong migration password>'
export TF_VAR_app_runtime_password='<strong runtime password>'
export SUPABASE_TFSTATE_DATABASE_URL='<Terraform-state database URL>'

cat > app-database.tfbackend <<EOF
conn_str = "$SUPABASE_TFSTATE_DATABASE_URL"
schema_name = "application_database_state"
EOF

terraform init -backend-config=app-database.tfbackend
terraform fmt -check
terraform validate
terraform plan
terraform apply
terraform output -raw supabase_project_ref
```

For an existing project, initialise the backend and import it before planning:

```sh
terraform import supabase_project.catalogue '<project-ref>'
terraform import supabase_settings.catalogue '<project-ref>'
terraform plan
```

After verification, set the resulting project reference as `SUPABASE_PROJECT_REF` for the main
infrastructure deployment. Restrict or remove access to the creation credentials.
