resource "null_resource" "bedrock_graphrag_cli" {
  count = var.enable_bedrock_cli ? 1 : 0

  triggers = {
    aws_region      = var.aws_region
    raw_bucket      = aws_s3_bucket.raw.id
    curated_bucket  = aws_s3_bucket.curated.id
    kb_role_arn     = aws_iam_role.bedrock_kb_role.arn
    embedding_model = var.embedding_model_arn
    graph_model     = var.graph_enrichment_model_arn
    script_hash     = filesha256("${path.module}/../../scripts/aws_cli/create_bedrock_graphrag_kb.sh")
    destroy_hash    = filesha256("${path.module}/../../scripts/aws_cli/destroy_bedrock_graphrag_kb.sh")
  }

  provisioner "local-exec" {
    working_dir = "${path.module}/../.."
    command     = "bash scripts/aws_cli/create_bedrock_graphrag_kb.sh"
    environment = {
      AWS_REGION                 = var.aws_region
      PROJECT_NAME               = local.name_prefix
      RAW_BUCKET                 = aws_s3_bucket.raw.id
      CURATED_BUCKET             = aws_s3_bucket.curated.id
      BEDROCK_KB_ROLE_ARN        = aws_iam_role.bedrock_kb_role.arn
      EMBEDDING_MODEL_ARN        = var.embedding_model_arn
      GRAPH_ENRICHMENT_MODEL_ARN = var.graph_enrichment_model_arn
      NEPTUNE_PROVISIONED_MEMORY = tostring(var.neptune_provisioned_memory)
    }
  }

  provisioner "local-exec" {
    when        = destroy
    working_dir = "${path.module}/../.."
    command     = "bash scripts/aws_cli/destroy_bedrock_graphrag_kb.sh"

    environment = {
      AWS_REGION = self.triggers.aws_region
    }
  }

  depends_on = [
    aws_s3_object.raw_data,
    aws_s3_object.curated_data,
    aws_opensearchserverless_collection.vector
  ]
}

resource "null_resource" "bedrock_guardrail_cli" {
  count = var.enable_bedrock_guardrail ? 1 : 0

  triggers = {
    aws_region   = var.aws_region
    project_name = local.name_prefix
    script_hash  = filesha256("${path.module}/../../scripts/aws_cli/create_guardrail.sh")
    destroy_hash = filesha256("${path.module}/../../scripts/aws_cli/destroy_guardrail.sh")
  }

  provisioner "local-exec" {
    working_dir = "${path.module}/../.."
    command     = "bash scripts/aws_cli/create_guardrail.sh"

    environment = {
      AWS_REGION   = var.aws_region
      PROJECT_NAME = local.name_prefix
    }
  }

  provisioner "local-exec" {
    when        = destroy
    working_dir = "${path.module}/../.."
    command     = "bash scripts/aws_cli/destroy_guardrail.sh"

    environment = {
      AWS_REGION = self.triggers.aws_region
    }
  }
}

resource "null_resource" "bedrock_graphrag_ingestion_cli" {
  count = var.enable_bedrock_cli ? 1 : 0

  triggers = {
    aws_region = var.aws_region
    source_etags = sha256(jsonencode({
      for k, v in aws_s3_object.raw_data : k => v.etag
    }))
  }

  provisioner "local-exec" {
    working_dir = "${path.module}/../.."
    command     = "bash scripts/aws_cli/start_ingestion_jobs.sh"

    environment = {
      AWS_REGION = var.aws_region
    }
  }

  depends_on = [null_resource.bedrock_graphrag_cli]
}
