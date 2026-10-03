resource "aws_iam_role" "gateway" {
  name = "tango-music-game-gateway"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "gateway_logs" {
  role       = aws_iam_role.gateway.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Scoped only to the target function names enumerated in
# var.gateway_target_function_names, which must stay in sync with
# backend/src/gateway_config/routes.json (least privilege, User Story 3).
data "aws_iam_policy_document" "gateway_invoke_targets" {
  statement {
    actions = ["lambda:InvokeFunction"]
    resources = [
      for name in var.gateway_target_function_names :
      "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:${name}"
    ]
  }
}

resource "aws_iam_role_policy" "gateway_invoke_targets" {
  role   = aws_iam_role.gateway.id
  policy = data.aws_iam_policy_document.gateway_invoke_targets.json
}

# Encrypted at rest by AWS-owned keys by default (no charge); a customer-managed
# KMS key was deliberately not added here, since CMKs bill a flat $1/month each
# regardless of usage and buy no additional requirement for this project.
resource "aws_cloudwatch_log_group" "gateway" {
  name              = "/aws/lambda/tango-music-game-gateway"
  retention_in_days = var.log_retention_days

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_lambda_function" "gateway" {
  function_name    = "tango-music-game-gateway"
  role             = aws_iam_role.gateway.arn
  handler          = "src.handlers.gateway.lambda_handler"
  runtime          = "python3.12"
  architectures    = ["arm64"]
  filename         = data.external.lambda_package["gateway"].result.path
  source_code_hash = data.external.lambda_package["gateway"].result.sha256_base64
  # Comfortably exceeds the routing configuration's ~29s maximum per-route
  # forwarding timeout so the gateway itself is never killed before it can
  # return a clean 504 to the client.
  timeout                        = 30
  memory_size                    = 256
  reserved_concurrent_executions = var.lambda_reserved_concurrency

  environment {
    variables = {
      LOG_LEVEL = "INFO"
    }
  }

  depends_on = [aws_cloudwatch_log_group.gateway]
}
