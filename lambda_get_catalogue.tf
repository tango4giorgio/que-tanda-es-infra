resource "aws_iam_role" "get_catalogue" {
  name = "tango-music-game-get-catalogue"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "get_catalogue_logs" {
  role       = aws_iam_role.get_catalogue.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "get_catalogue_secret" {
  role   = aws_iam_role.get_catalogue.id
  policy = data.aws_iam_policy_document.database_secret_read.json
}

resource "aws_lambda_function" "get_catalogue" {
  function_name    = "tango-music-game-get-catalogue"
  role             = aws_iam_role.get_catalogue.arn
  handler          = "src.handlers.get_catalogue.lambda_handler"
  runtime          = "python3.12"
  architectures    = ["arm64"]
  filename         = var.lambda_package_path
  source_code_hash = filebase64sha256(var.lambda_package_path)
  timeout          = 10
  memory_size      = 256

  environment {
    variables = {
      DATABASE_URL_SECRET_ARN = aws_secretsmanager_secret.database_url.arn
    }
  }
}
