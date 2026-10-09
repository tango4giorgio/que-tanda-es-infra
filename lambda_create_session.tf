resource "aws_iam_role" "create_session" {
  name = "tango-music-game-create-session"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "create_session_logs" {
  role       = aws_iam_role.create_session.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Same SSM read permission as the other gameplay-endpoint roles (the database connection
# string is read-only from this Lambda's perspective too; the write happens over the
# resulting Postgres connection, not via any additional AWS-level permission).
resource "aws_iam_role_policy" "create_session_secret" {
  role   = aws_iam_role.create_session.id
  policy = data.aws_iam_policy_document.database_parameter_read.json
}

# Encrypted at rest by AWS-owned keys by default (no charge); a customer-managed
# KMS key was deliberately not added here, since CMKs bill a flat $1/month each
# regardless of usage and buy no additional requirement for this project.
resource "aws_cloudwatch_log_group" "create_session" {
  name              = "/aws/lambda/tango-music-game-create-session"
  retention_in_days = var.log_retention_days

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_lambda_function" "create_session" {
  function_name                  = "tango-music-game-create-session"
  role                           = aws_iam_role.create_session.arn
  handler                        = "src.handlers.create_session.lambda_handler"
  runtime                        = "python3.12"
  architectures                  = ["arm64"]
  filename                       = data.external.lambda_package["create_session"].result.path
  source_code_hash               = data.external.lambda_package["create_session"].result.sha256_base64
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

  depends_on = [aws_cloudwatch_log_group.create_session]
}
