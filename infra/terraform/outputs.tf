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

output "datazone_domain_id" {
  value = var.enable_datazone ? aws_datazone_domain.demo[0].id : null
}

output "static_demo_site_url" {
  value = var.enable_static_demo_site ? "http://${aws_s3_bucket_website_configuration.app[0].website_endpoint}" : null
}
