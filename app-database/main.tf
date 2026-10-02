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
