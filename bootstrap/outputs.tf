output "deployer_user_name" {
  value = aws_iam_user.deployer.name
}

output "deployer_access_key_id" {
  value = aws_iam_access_key.deployer.id
}

output "deployer_secret_access_key" {
  value     = aws_iam_access_key.deployer.secret
  sensitive = true
}

output "github_actions_role_arn" {
  value = aws_iam_role.github_actions_deployer.arn
}

output "github_actions_oidc_subject" {
  value       = "repo:${split("/", var.github_repository)[0]}@${var.github_repository_owner_id}/${split("/", var.github_repository)[1]}@${var.github_repository_id}:environment:${var.github_environment}"
  description = "Exact immutable GitHub OIDC subject trusted by the deployment role."
}

output "tfstate_project_ref" {
  value       = supabase_project.tfstate.id
  description = "Project reference for the dedicated Terraform-state Supabase project, useful for finding it in the dashboard."
}

output "tfstate_database_url" {
  value       = local.tfstate_database_url
  description = "Postgres connection string for Terraform's pg backend (conn_str). Contains credentials; never commit it."
  sensitive   = true
}
