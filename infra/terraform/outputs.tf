output "raw_bucket" {
  value = aws_s3_bucket.raw.id
}

output "curated_bucket" {
  value = aws_s3_bucket.curated.id
}

output "opensearch_collection_endpoint" {
  value = aws_opensearchserverless_collection.vector.collection_endpoint
}

output "lambda_create_claim_case" {
  value = aws_lambda_function.create_claim_case.function_name
}

output "lambda_request_card_block" {
  value = aws_lambda_function.request_card_block.function_name
}

output "dynamodb_tables" {
  value = { for k, v in aws_dynamodb_table.tables : k => v.name }
}

output "bedrock_kb_role_arn" {
  value = aws_iam_role.bedrock_kb_role.arn
}

output "bedrock_guardrail_id" {
  value = var.enable_bedrock_guardrail ? aws_bedrock_guardrail.banking[0].guardrail_id : null
}

output "bedrock_basic_knowledge_base_id" {
  value = var.enable_basic_rag ? aws_bedrockagent_knowledge_base.basic_rag[0].id : null
}

output "bedrock_basic_data_source_id" {
  value = var.enable_basic_rag ? aws_bedrockagent_data_source.basic_rag[0].data_source_id : null
}

output "bedrock_graphrag_knowledge_base_id" {
  value = var.enable_graphrag ? aws_bedrockagent_knowledge_base.graphrag[0].id : null
}

output "bedrock_graphrag_data_source_id" {
  value = var.enable_graphrag ? aws_cloudformation_stack.graphrag_data_source[0].outputs["DataSourceId"] : null
}

output "neptune_graph_arn" {
  value = var.enable_graphrag ? aws_neptunegraph_graph.graphrag[0].arn : null
}

output "datazone_domain_id" {
  value = var.enable_datazone ? aws_datazone_domain.demo[0].id : null
}

output "static_demo_site_url" {
  value = var.enable_static_demo_site ? "http://${aws_s3_bucket_website_configuration.app[0].website_endpoint}" : null
}

output "rag_api_url" {
  value = "${aws_apigatewayv2_api.rag.api_endpoint}/query"
}
