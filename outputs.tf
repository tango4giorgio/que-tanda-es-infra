output "game_api_url" {
  value = aws_apigatewayv2_stage.default.invoke_url
}

output "get_game_lambda_arn" {
  value = aws_lambda_function.get_game.arn
}

output "get_previews_lambda_arn" {
  value = aws_lambda_function.get_previews.arn
}

output "gateway_endpoint" {
  value = aws_apigatewayv2_stage.gateway_default.invoke_url
}

output "gateway_lambda_arn" {
  value = aws_lambda_function.gateway.arn
}

output "supabase_project_ref" {
  value = supabase_project.catalogue.id
}

output "supabase_project_url" {
  value = "https://${supabase_project.catalogue.id}.supabase.co"
}

output "supabase_database_host" {
  value = "aws-0-${var.supabase_region}.pooler.supabase.com"
}

output "supabase_database_port" {
  value = 6543
}

output "supabase_database_url" {
  value     = local.supabase_pooler_database_url
  sensitive = true
}
