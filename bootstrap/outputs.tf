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

output "terraform_state_bucket_name" {
  value = aws_s3_bucket.terraform_state.id
}

output "terraform_lock_table_name" {
  value = aws_dynamodb_table.terraform_locks.name
}
