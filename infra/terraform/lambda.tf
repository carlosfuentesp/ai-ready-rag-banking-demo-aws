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
