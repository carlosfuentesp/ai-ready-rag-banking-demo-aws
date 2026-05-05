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

resource "aws_neptunegraph_graph" "graphrag" {
  count = var.enable_graphrag ? 1 : 0

  graph_name          = local.graphrag_neptune_graph
  provisioned_memory  = var.neptune_graph_provisioned_memory
  public_connectivity = false
  deletion_protection = false

  vector_search_configuration {
    vector_search_dimension = var.embedding_dimension
  }
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
    type = "NEPTUNE_ANALYTICS"

    neptune_analytics_configuration {
      graph_arn = aws_neptunegraph_graph.graphrag[0].arn

      field_mapping {
        metadata_field = "metadata"
        text_field     = "text"
      }
    }
  }

  timeouts {
    create = "60m"
    delete = "60m"
  }

  depends_on = [
    aws_iam_role_policy.bedrock_kb_policy,
    aws_neptunegraph_graph.graphrag,
  ]
}

resource "aws_cloudformation_stack" "graphrag_data_source" {
  count = var.enable_graphrag ? 1 : 0

  name               = "${local.name_prefix}-graphrag-ds"
  timeout_in_minutes = 60

  template_body = jsonencode({
    AWSTemplateFormatVersion = "2010-09-09"
    Description              = "Bedrock GraphRAG data source with context enrichment managed by Terraform through CloudFormation."
    Resources = {
      GraphRagDataSource = {
        Type = "AWS::Bedrock::DataSource"
        Properties = {
          KnowledgeBaseId    = aws_bedrockagent_knowledge_base.graphrag[0].id
          Name               = "${local.name_prefix}_graphrag_source"
          Description        = "Synthetic banking documents for AI-Ready GraphRAG with semantic chunking and entity extraction."
          DataDeletionPolicy = "DELETE"
          DataSourceConfiguration = {
            Type = "S3"
            S3Configuration = {
              BucketArn         = aws_s3_bucket.raw.arn
              InclusionPrefixes = ["raw/documents/"]
            }
          }
          VectorIngestionConfiguration = {
            ChunkingConfiguration = {
              ChunkingStrategy = "SEMANTIC"
              SemanticChunkingConfiguration = {
                BreakpointPercentileThreshold = 75
                BufferSize                    = 1
                MaxTokens                     = var.semantic_chunking_max_tokens
              }
            }
            ContextEnrichmentConfiguration = {
              Type = "BEDROCK_FOUNDATION_MODEL"
              BedrockFoundationModelConfiguration = {
                ModelArn = local.graph_context_model_arn
                EnrichmentStrategyConfiguration = {
                  Method = "CHUNK_ENTITY_EXTRACTION"
                }
              }
            }
          }
        }
      }
    }
    Outputs = {
      DataSourceId = {
        Value = {
          "Fn::GetAtt" = ["GraphRagDataSource", "DataSourceId"]
        }
      }
    }
  })

  depends_on = [
    aws_s3_object.raw_data,
    aws_bedrockagent_knowledge_base.graphrag,
  ]
}
