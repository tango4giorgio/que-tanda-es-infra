resource "aws_apigatewayv2_api" "game" {
  name          = "tango-music-game"
  protocol_type = "HTTP"
  cors_configuration {
    allow_headers = ["content-type"]
    allow_methods = ["GET", "POST"]
    allow_origins = ["*"]
    max_age       = 3600
  }
}

resource "aws_apigatewayv2_integration" "get_game" {
  api_id                 = aws_apigatewayv2_api.game.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.get_game.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "get_game" {
  api_id    = aws_apigatewayv2_api.game.id
  route_key = "GET /game"
  target    = "integrations/${aws_apigatewayv2_integration.get_game.id}"
}

resource "aws_apigatewayv2_integration" "get_previews" {
  api_id                 = aws_apigatewayv2_api.game.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.get_previews.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "get_previews" {
  api_id    = aws_apigatewayv2_api.game.id
  route_key = "POST /previews"
  target    = "integrations/${aws_apigatewayv2_integration.get_previews.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.game.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "get_game_api_gateway" {
  statement_id  = "AllowApiGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_game.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.game.execution_arn}/*/GET/game"
}

resource "aws_lambda_permission" "get_previews_api_gateway" {
  statement_id  = "AllowApiGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_previews.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.game.execution_arn}/*/POST/previews"
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
