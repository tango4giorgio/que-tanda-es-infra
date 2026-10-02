resource "supabase_project" "catalogue" {
  organization_id   = var.supabase_organization_id
  name              = var.supabase_project_name
  database_password = var.supabase_database_password
  region            = var.supabase_region
  # instance_size intentionally omitted: the "nano" compute class has a
  # known bug in the Supabase Terraform provider/platform (resizing away
  # from it does not stick), so leave this unset and manage compute size
  # manually in the Supabase dashboard if it's ever needed.

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

locals {
  # Least-privilege runtime role (SELECT/INSERT/UPDATE + EXECUTE on functions only, no DDL —
  # see backend/src/migrations/0003_create_database_roles.sql). This is the only credential
  # stored in SSM and read by the deployed Lambdas.
  supabase_pooler_database_url = format(
    "postgresql://%s:%s@aws-0-%s.pooler.supabase.com:6543/postgres?sslmode=require",
    urlencode("app_runtime.${supabase_project.catalogue.id}"),
    urlencode(var.app_runtime_password),
    var.supabase_region,
  )

  # Session-mode pooler (port 5432, required for the role/schema DDL statements migrations run)
  # connection string for the migration_runner role. Never stored in SSM or read by the
  # Lambdas — it is only surfaced via the sensitive migration_database_url output, for a human
  # or the release-time migration workflow to copy into that workflow's own secret store.
  supabase_migration_database_url = format(
    "postgresql://%s:%s@aws-0-%s.pooler.supabase.com:5432/postgres?sslmode=require",
    urlencode("migration_runner.${supabase_project.catalogue.id}"),
    urlencode(var.migration_runner_password),
    var.supabase_region,
  )
}
