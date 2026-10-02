resource "supabase_project" "catalogue" {
  organization_id   = var.supabase_organization_id
  name              = var.supabase_project_name
  database_password = var.supabase_database_password
  region            = var.supabase_region

  lifecycle {
    prevent_destroy = true
  }

  timeouts {
    create = "30m"
    update = "30m"
  }
}

resource "supabase_settings" "catalogue" {
  project_ref     = supabase_project.catalogue.id
  ssl_enforcement = true

  api = jsonencode({
    db_schema            = "public,storage,graphql_public"
    db_extra_search_path = "public,extensions"
    max_rows             = 1000
  })
}

resource "terraform_data" "database_roles" {
  triggers_replace = [
    supabase_project.catalogue.id,
    filesha256("${path.module}/create_roles.sql"),
    sha256(var.migration_runner_password),
    sha256(var.app_runtime_password),
  ]

  provisioner "local-exec" {
    working_dir = path.module
    command     = <<-EOT
      psql \
        --no-psqlrc \
        --set ON_ERROR_STOP=1 \
        -v migration_runner_password="$MIGRATION_RUNNER_PASSWORD" \
        -v app_runtime_password="$APP_RUNTIME_PASSWORD" \
        -f create_roles.sql
    EOT

    environment = {
      PGHOST                    = "aws-0-${var.supabase_region}.pooler.supabase.com"
      PGPORT                    = "5432"
      PGDATABASE                = "postgres"
      PGUSER                    = "postgres.${supabase_project.catalogue.id}"
      PGPASSWORD                = var.supabase_database_password
      PGSSLMODE                 = "require"
      MIGRATION_RUNNER_PASSWORD = var.migration_runner_password
      APP_RUNTIME_PASSWORD      = var.app_runtime_password
    }
  }

  depends_on = [supabase_settings.catalogue]
}
