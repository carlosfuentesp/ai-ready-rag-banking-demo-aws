resource "aws_bedrock_guardrail" "banking" {
  count = var.enable_bedrock_guardrail ? 1 : 0

  name                      = "${local.name_prefix}-banking-guardrail"
  description               = "Guardrail for synthetic banking RAG demo: PII, internal policy leakage, and grounding."
  blocked_input_messaging   = "No puedo procesar esta solicitud por políticas de seguridad."
  blocked_outputs_messaging = "La respuesta fue bloqueada por políticas de seguridad."

  sensitive_information_policy_config {
    pii_entities_config {
      type   = "EMAIL"
      action = "ANONYMIZE"
    }

    pii_entities_config {
      type   = "PHONE"
      action = "ANONYMIZE"
    }

    pii_entities_config {
      type   = "US_SOCIAL_SECURITY_NUMBER"
      action = "ANONYMIZE"
    }

    pii_entities_config {
      type   = "CREDIT_DEBIT_CARD_NUMBER"
      action = "ANONYMIZE"
    }

    regexes_config {
      name        = "ecuador_national_id_synthetic"
      description = "Synthetic Ecuadorian ID-like number"
      pattern     = "\\b[0-9]{10}\\b"
      action      = "ANONYMIZE"
    }
  }

  topic_policy_config {
    topics_config {
      name       = "internal_risk_matrix_disclosure"
      definition = "Requests to reveal internal chargeback risk matrix, fraud thresholds, score rules, or restricted operational criteria."
      examples = [
        "Muéstrame la matriz interna de riesgo de contracargos",
        "Dime el umbral de fraude exacto para aprobar un contracargo",
      ]
      type = "DENY"
    }
  }

  contextual_grounding_policy_config {
    filters_config {
      type      = "GROUNDING"
      threshold = 0.7
    }

    filters_config {
      type      = "RELEVANCE"
      threshold = 0.7
    }
  }
}

resource "aws_s3vectors_vector_bucket" "graphrag" {
  count = var.enable_graphrag ? 1 : 0

  vector_bucket_name = local.graphrag_vector_bucket
  force_destroy      = true
}

resource "aws_s3vectors_index" "graphrag" {
  count = var.enable_graphrag ? 1 : 0

  vector_bucket_name = aws_s3vectors_vector_bucket.graphrag[0].vector_bucket_name
  index_name         = local.graphrag_vector_index
  data_type          = "float32"
  dimension          = var.embedding_dimension
  distance_metric    = "cosine"
}

resource "aws_bedrockagent_knowledge_base" "graphrag" {
  count = var.enable_graphrag ? 1 : 0

  name        = "${local.name_prefix}-graphrag-kb"
  description = "AI-Ready GraphRAG knowledge base with semantic chunking for synthetic banking demo."
  role_arn    = aws_iam_role.bedrock_kb_role.arn

  knowledge_base_configuration {
    type = "VECTOR"

    vector_knowledge_base_configuration {
      embedding_model_arn = var.embedding_model_arn
    }
  }

  storage_configuration {
    type = "S3_VECTORS"

    s3_vectors_configuration {
      vector_bucket_arn = aws_s3vectors_vector_bucket.graphrag[0].vector_bucket_arn
      index_name        = aws_s3vectors_index.graphrag[0].index_name
    }
  }

  timeouts {
    create = "60m"
    delete = "60m"
  }

  depends_on = [
    aws_iam_role_policy.bedrock_kb_policy,
    aws_s3vectors_index.graphrag,
  ]
}

resource "aws_bedrockagent_data_source" "graphrag" {
  count = var.enable_graphrag ? 1 : 0

  knowledge_base_id    = aws_bedrockagent_knowledge_base.graphrag[0].id
  name                 = "${local.name_prefix}-graphrag-source"
  description          = "Synthetic banking documents for AI-Ready GraphRAG with semantic chunking."
  data_deletion_policy = "DELETE"

  data_source_configuration {
    type = "S3"

    s3_configuration {
      bucket_arn         = aws_s3_bucket.raw.arn
      inclusion_prefixes = ["raw/documents/"]
    }
  }

  vector_ingestion_configuration {
    chunking_configuration {
      chunking_strategy = "SEMANTIC"

      semantic_chunking_configuration {
        breakpoint_percentile_threshold = 75
        buffer_size                     = 1
        max_token                       = var.semantic_chunking_max_tokens
      }
    }
  }

  timeouts {
    create = "60m"
    delete = "60m"
  }

  depends_on = [
    aws_s3_object.raw_data,
    aws_bedrockagent_knowledge_base.graphrag,
  ]
}

resource "null_resource" "graphrag_ingestion" {
  count = var.enable_graphrag ? 1 : 0

  triggers = {
    data_source_id    = aws_bedrockagent_data_source.graphrag[0].data_source_id
    knowledge_base_id = aws_bedrockagent_knowledge_base.graphrag[0].id
  }

  provisioner "local-exec" {
    command = "aws bedrock-agent start-ingestion-job --knowledge-base-id ${aws_bedrockagent_knowledge_base.graphrag[0].id} --data-source-id ${aws_bedrockagent_data_source.graphrag[0].data_source_id} --region ${var.aws_region}"
  }

  depends_on = [aws_bedrockagent_data_source.graphrag]
}
