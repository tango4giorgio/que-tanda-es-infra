resource "supabase_project" "catalogue" {
  organization_id   = var.supabase_organization_id
  name              = var.supabase_project_name
  database_password = var.supabase_database_password
  region            = var.supabase_region
  instance_size     = var.supabase_instance_size

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
  supabase_pooler_database_url = format(
    "postgresql://%s:%s@aws-0-%s.pooler.supabase.com:6543/postgres?sslmode=require",
    urlencode("postgres.${supabase_project.catalogue.id}"),
    urlencode(var.supabase_database_password),
    var.supabase_region,
  )
}
