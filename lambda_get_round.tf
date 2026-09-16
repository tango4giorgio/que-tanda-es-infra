resource "aws_iam_role" "get_round" {
  name = "tango-music-game-get-round"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "get_round_logs" {
  role       = aws_iam_role.get_round.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "get_round_secret" {
  role   = aws_iam_role.get_round.id
  policy = data.aws_iam_policy_document.database_parameter_read.json
}

data "aws_caller_identity" "current" {}

# Encrypted at rest by AWS-owned keys by default (no charge); a customer-managed
# KMS key was deliberately not added here, since CMKs bill a flat $1/month each
# regardless of usage and buy no additional requirement for this project.
resource "aws_cloudwatch_log_group" "get_round" {
  name              = "/aws/lambda/tango-music-game-get-round"
  retention_in_days = var.log_retention_days
}

resource "aws_lambda_function" "get_round" {
  function_name                  = "tango-music-game-get-round"
  role                           = aws_iam_role.get_round.arn
  handler                        = "src.handlers.get_round.lambda_handler"
  runtime                        = "python3.12"
  architectures                  = ["arm64"]
  filename                       = data.external.lambda_package["get_round"].result.path
  source_code_hash               = data.external.lambda_package["get_round"].result.sha256_base64
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

  depends_on = [aws_cloudwatch_log_group.get_round]
}
