check "game_route_is_read_only" {
  assert {
    condition     = aws_apigatewayv2_route.get_game.route_key == "GET /game"
    error_message = "The game creation API must remain GET-only."
  }
}

check "transaction_pooler_is_used" {
  assert {
    condition     = strcontains(local.supabase_pooler_database_url, "pooler.supabase.com:6543")
    error_message = "Lambda must use the Supabase transaction pooler."
  }
}

check "lambda_concurrency_is_valid" {
  assert {
    condition = alltrue([
      for concurrency in [
        aws_lambda_function.gateway.reserved_concurrent_executions,
        aws_lambda_function.get_game.reserved_concurrent_executions,
        aws_lambda_function.get_previews.reserved_concurrent_executions,
        aws_lambda_function.submit_feedback.reserved_concurrent_executions,
        aws_lambda_function.create_session.reserved_concurrent_executions,
      ] : concurrency == -1 || concurrency > 0
    ])
    error_message = "Lambda concurrency must use the shared unreserved pool or a positive reservation."
  }
}

check "gateway_invoke_policy_is_scoped" {
  assert {
    condition = !contains(
      flatten([for statement in jsondecode(data.aws_iam_policy_document.gateway_invoke_targets.json).Statement : statement.Resource]),
      "*"
    )
    error_message = "The gateway's invoke-permission policy must not include a wildcard resource."
  }
}
