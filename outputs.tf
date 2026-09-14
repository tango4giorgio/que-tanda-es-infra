output "catalogue_api_url" {
  value = aws_apigatewayv2_stage.default.invoke_url
}

output "get_catalogue_lambda_arn" {
  value = aws_lambda_function.get_catalogue.arn
}

output "supabase_project_ref" {
  value = supabase_project.catalogue.id
}

output "supabase_project_url" {
  value = "https://${supabase_project.catalogue.id}.supabase.co"
}

output "supabase_database_host" {
  value = "db.${supabase_project.catalogue.id}.supabase.co"
}

output "supabase_database_url" {
  value     = local.supabase_database_url
  sensitive = true
}
