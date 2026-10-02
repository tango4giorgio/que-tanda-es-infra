output "supabase_project_ref" {
  description = "Set this as SUPABASE_PROJECT_REF in the main infrastructure production environment."
  value       = supabase_project.catalogue.id
}

output "supabase_project_url" {
  value = "https://${supabase_project.catalogue.id}.supabase.co"
}

output "supabase_session_pooler_host" {
  description = "Session-pooler host used by Terraform role management and release migrations on port 5432."
  value       = "aws-0-${var.supabase_region}.pooler.supabase.com"
}
