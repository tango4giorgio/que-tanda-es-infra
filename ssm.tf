# Standard-tier SecureString parameter (AWS-managed KMS key, no per-secret or
# customer-managed-key charge) storing the Supabase transaction-pooler
# connection string, kept out of plain Lambda environment variables.
resource "aws_ssm_parameter" "database_url" {
  name  = var.database_url_parameter_name
  type  = "SecureString"
  value = local.supabase_pooler_database_url
}

data "aws_iam_policy_document" "database_parameter_read" {
  statement {
    actions   = ["ssm:GetParameter"]
    resources = [aws_ssm_parameter.database_url.arn]
  }
}
