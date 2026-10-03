resource "aws_iam_role" "submit_feedback" {
  name = "tango-music-game-submit-feedback"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "submit_feedback_logs" {
  role       = aws_iam_role.submit_feedback.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Same SSM read permission as the game and preview roles (the database connection string
# is read-only from this Lambda's perspective too; the write happens over the
# resulting Postgres connection, not via any additional AWS-level permission).
resource "aws_iam_role_policy" "submit_feedback_secret" {
  role   = aws_iam_role.submit_feedback.id
  policy = data.aws_iam_policy_document.database_parameter_read.json
}

# Encrypted at rest by AWS-owned keys by default (no charge); a customer-managed
# KMS key was deliberately not added here, since CMKs bill a flat $1/month each
# regardless of usage and buy no additional requirement for this project.
resource "aws_cloudwatch_log_group" "submit_feedback" {
  name              = "/aws/lambda/tango-music-game-submit-feedback"
  retention_in_days = var.log_retention_days

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_lambda_function" "submit_feedback" {
  function_name                  = "tango-music-game-submit-feedback"
  role                           = aws_iam_role.submit_feedback.arn
  handler                        = "src.handlers.submit_feedback.lambda_handler"
  runtime                        = "python3.12"
  architectures                  = ["arm64"]
  filename                       = data.external.lambda_package["submit_feedback"].result.path
  source_code_hash               = data.external.lambda_package["submit_feedback"].result.sha256_base64
  timeout                        = 10
  memory_size                    = 256
  reserved_concurrent_executions = var.lambda_reserved_concurrency

  environment {
    variables = {
      DATABASE_URL_PARAMETER_NAME      = aws_ssm_parameter.database_url.name
      DATABASE_CONNECT_TIMEOUT_SECONDS = "5"
      DATABASE_STATEMENT_TIMEOUT_MS    = "5000"
      DEPLOYED_ENVIRONMENT             = "production"
      LOG_LEVEL                        = "INFO"
    }
  }

  depends_on = [aws_cloudwatch_log_group.submit_feedback]
}
