resource "aws_apigatewayv2_api" "catalogue" {
  name          = "tango-music-game-catalogue"
  protocol_type = "HTTP"
  cors_configuration {
    allow_methods = ["GET"]
    allow_origins = ["*"]
  }
}

resource "aws_apigatewayv2_integration" "get_catalogue" {
  api_id                 = aws_apigatewayv2_api.catalogue.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.get_catalogue.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "get_catalogue" {
  api_id    = aws_apigatewayv2_api.catalogue.id
  route_key = "GET /catalogue"
  target    = "integrations/${aws_apigatewayv2_integration.get_catalogue.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.catalogue.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowApiGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_catalogue.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.catalogue.execution_arn}/*/*"
}
