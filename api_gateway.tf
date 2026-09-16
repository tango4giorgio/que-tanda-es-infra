resource "aws_apigatewayv2_api" "round" {
  name          = "tango-music-game-round"
  protocol_type = "HTTP"
  cors_configuration {
    allow_headers = ["content-type"]
    allow_methods = ["GET"]
    allow_origins = ["*"]
    max_age       = 3600
  }
}

resource "aws_apigatewayv2_integration" "get_round" {
  api_id                 = aws_apigatewayv2_api.round.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.get_round.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "get_round" {
  api_id    = aws_apigatewayv2_api.round.id
  route_key = "GET /round"
  target    = "integrations/${aws_apigatewayv2_integration.get_round.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.round.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowApiGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_round.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.round.execution_arn}/*/GET/round"
}

# The gateway's own single entry point: a catch-all $default route forwards
# every request to the gateway Lambda, which performs its own method+path
# routing against the static routing configuration bundled in its package.
resource "aws_apigatewayv2_api" "gateway" {
  name          = "tango-music-game-gateway"
  protocol_type = "HTTP"
  cors_configuration {
    allow_headers = ["content-type"]
    allow_methods = ["GET", "POST", "PUT", "PATCH", "DELETE"]
    allow_origins = ["*"]
    max_age       = 3600
  }
}

resource "aws_apigatewayv2_integration" "gateway" {
  api_id                 = aws_apigatewayv2_api.gateway.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.gateway.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "gateway_default" {
  api_id    = aws_apigatewayv2_api.gateway.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.gateway.id}"
}

resource "aws_apigatewayv2_stage" "gateway_default" {
  api_id      = aws_apigatewayv2_api.gateway.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "gateway_api_gateway" {
  statement_id  = "AllowApiGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.gateway.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.gateway.execution_arn}/*/*"
}
