resource "aws_secretsmanager_secret" "database_url" {
  name = var.database_url_secret_name
}

resource "aws_secretsmanager_secret_version" "database_url" {
  secret_id     = aws_secretsmanager_secret.database_url.id
  secret_string = local.supabase_database_url
}

data "aws_iam_policy_document" "database_secret_read" {
  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.database_url.arn]
  }
}
