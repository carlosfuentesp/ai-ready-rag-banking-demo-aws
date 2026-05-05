data "archive_file" "create_claim_case" {
  type        = "zip"
  source_dir  = "${path.module}/../../lambdas/create_claim_case"
  output_path = "${path.module}/.terraform/create_claim_case.zip"
}

data "archive_file" "request_card_block" {
  type        = "zip"
  source_dir  = "${path.module}/../../lambdas/request_card_block"
  output_path = "${path.module}/.terraform/request_card_block.zip"
}

data "archive_file" "query_rag" {
  type        = "zip"
  source_dir  = "${path.module}/../../lambdas/query_rag"
  output_path = "${path.module}/.terraform/query_rag.zip"
}

data "archive_file" "start_ingestion" {
  type        = "zip"
  source_dir  = "${path.module}/../../lambdas/start_ingestion"
  output_path = "${path.module}/.terraform/start_ingestion.zip"
}

resource "aws_lambda_function" "create_claim_case" {
  function_name    = "${local.name_prefix}-create-claim-case"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.11"
  filename         = data.archive_file.create_claim_case.output_path
  source_code_hash = data.archive_file.create_claim_case.output_base64sha256
  timeout          = 30

  environment {
    variables = {
      CLAIMS_TABLE = aws_dynamodb_table.tables["claims"].name
      AUDIT_TABLE  = aws_dynamodb_table.tables["audit_events"].name
    }
  }
}

resource "aws_lambda_function" "request_card_block" {
  function_name    = "${local.name_prefix}-request-card-block"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.11"
  filename         = data.archive_file.request_card_block.output_path
  source_code_hash = data.archive_file.request_card_block.output_base64sha256
  timeout          = 30

  environment {
    variables = {
      AUDIT_TABLE = aws_dynamodb_table.tables["audit_events"].name
    }
  }
}

resource "aws_lambda_function" "query_rag" {
  function_name    = "${local.name_prefix}-query-rag"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.11"
  filename         = data.archive_file.query_rag.output_path
  source_code_hash = data.archive_file.query_rag.output_base64sha256
  timeout          = 60

  environment {
    variables = {
      BASIC_KB_ID         = var.enable_basic_rag ? aws_bedrockagent_knowledge_base.basic_rag[0].id : ""
      AI_READY_KB_ID      = var.enable_graphrag ? aws_bedrockagent_knowledge_base.graphrag[0].id : ""
      GENERATION_MODEL_ID = var.generation_model_id
      TRANSACTIONS_TABLE  = aws_dynamodb_table.tables["transactions"].name
      PRODUCTS_TABLE      = aws_dynamodb_table.tables["products"].name
      CUSTOMERS_TABLE     = aws_dynamodb_table.tables["customers"].name
      GRAPH_NODES_TABLE   = aws_dynamodb_table.tables["graph_nodes"].name
      GRAPH_EDGES_TABLE   = aws_dynamodb_table.tables["graph_edges"].name
      LINEAGE_TABLE       = aws_dynamodb_table.tables["lineage_events"].name
      GUARDRAIL_ID        = var.enable_bedrock_guardrail ? aws_bedrock_guardrail.banking[0].guardrail_id : ""
      GUARDRAIL_VERSION   = var.enable_bedrock_guardrail ? aws_bedrock_guardrail.banking[0].version : ""
    }
  }

  depends_on = [
    aws_iam_role_policy.lambda_rag_access,
    aws_bedrockagent_data_source.basic_rag,
    aws_cloudformation_stack.graphrag_data_source,
  ]
}

resource "aws_lambda_function" "start_ingestion" {
  function_name    = "${local.name_prefix}-start-ingestion"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.11"
  filename         = data.archive_file.start_ingestion.output_path
  source_code_hash = data.archive_file.start_ingestion.output_base64sha256
  timeout          = 900

  environment {
    variables = {
      DEFAULT_WAIT_SECONDS = tostring(var.ingestion_wait_seconds)
    }
  }

  depends_on = [aws_iam_role_policy.lambda_ingestion_access]
}

resource "aws_lambda_invocation" "basic_rag_ingestion" {
  count = var.enable_basic_rag && var.auto_start_ingestion_jobs ? 1 : 0

  function_name = aws_lambda_function.start_ingestion.function_name
  input = jsonencode({
    knowledge_base_id = aws_bedrockagent_knowledge_base.basic_rag[0].id
    data_source_id    = aws_bedrockagent_data_source.basic_rag[0].data_source_id
    wait_seconds      = var.ingestion_wait_seconds
  })

  triggers = {
    knowledge_base_id = aws_bedrockagent_knowledge_base.basic_rag[0].id
    data_source_id    = aws_bedrockagent_data_source.basic_rag[0].data_source_id
    raw_data_hash     = sha256(join("", [for _, object in aws_s3_object.raw_data : object.etag]))
  }

  depends_on = [aws_bedrockagent_data_source.basic_rag]
}

resource "aws_lambda_invocation" "graphrag_ingestion" {
  count = var.enable_graphrag && var.auto_start_ingestion_jobs ? 1 : 0

  function_name = aws_lambda_function.start_ingestion.function_name
  input = jsonencode({
    knowledge_base_id = aws_bedrockagent_knowledge_base.graphrag[0].id
    data_source_id    = aws_cloudformation_stack.graphrag_data_source[0].outputs["DataSourceId"]
    wait_seconds      = var.ingestion_wait_seconds
  })

  triggers = {
    knowledge_base_id = aws_bedrockagent_knowledge_base.graphrag[0].id
    data_source_id    = aws_cloudformation_stack.graphrag_data_source[0].outputs["DataSourceId"]
    raw_data_hash     = sha256(join("", [for _, object in aws_s3_object.raw_data : object.etag]))
  }

  depends_on = [aws_cloudformation_stack.graphrag_data_source]
}
