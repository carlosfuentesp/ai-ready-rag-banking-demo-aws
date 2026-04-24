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
    }
  }

  depends_on = [
    aws_iam_role_policy.lambda_rag_access,
    aws_bedrockagent_data_source.basic_rag,
    aws_cloudformation_stack.graphrag_data_source,
  ]
}
