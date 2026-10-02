removed {
  from = supabase_settings.catalogue

  lifecycle {
    destroy = false
  }
}

removed {
  from = supabase_project.catalogue

  lifecycle {
    destroy = false
  }
}

locals {
  # Least-privilege runtime role (SELECT/INSERT/UPDATE + EXECUTE on functions only, no DDL —
  # see backend/src/database/bootstrap/create_roles.sql). This is the only database credential
  # stored in SSM and read by the deployed Lambdas.
  supabase_pooler_database_url = format(
    "postgresql://%s:%s@aws-0-%s.pooler.supabase.com:6543/postgres?sslmode=require",
    urlencode("app_runtime.${var.supabase_project_ref}"),
    urlencode(var.app_runtime_password),
    var.supabase_region,
  )
}
