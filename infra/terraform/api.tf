resource "aws_apigatewayv2_api" "rag" {
  name          = "${local.name_prefix}-rag-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_headers = ["content-type"]
    allow_methods = ["OPTIONS", "POST"]
    allow_origins = ["*"]
    max_age       = 300
  }
}

resource "aws_apigatewayv2_integration" "query_rag" {
  api_id                 = aws_apigatewayv2_api.rag.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.query_rag.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "query_rag" {
  api_id    = aws_apigatewayv2_api.rag.id
  route_key = "POST /query"
  target    = "integrations/${aws_apigatewayv2_integration.query_rag.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.rag.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "api_query_rag" {
  statement_id  = "AllowApiGatewayInvokeQueryRag"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.query_rag.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.rag.execution_arn}/*/*"
}
