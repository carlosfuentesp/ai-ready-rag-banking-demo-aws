resource "aws_s3vectors_vector_bucket" "basic_rag" {
  count = var.enable_basic_rag ? 1 : 0

  vector_bucket_name = local.basic_vector_bucket
  force_destroy      = true
}

resource "aws_s3vectors_index" "basic_rag" {
  count = var.enable_basic_rag ? 1 : 0

  vector_bucket_name = aws_s3vectors_vector_bucket.basic_rag[0].vector_bucket_name
  index_name         = local.basic_vector_index
  data_type          = "float32"
  dimension          = var.embedding_dimension
  distance_metric    = "cosine"
}

resource "aws_bedrockagent_knowledge_base" "basic_rag" {
  count = var.enable_basic_rag ? 1 : 0

  name        = "${local.name_prefix}-basic-rag-kb"
  description = "Basic RAG knowledge base with fixed-size chunking over raw PDFs only."
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
      vector_bucket_arn = aws_s3vectors_vector_bucket.basic_rag[0].vector_bucket_arn
      index_name        = aws_s3vectors_index.basic_rag[0].index_name
    }
  }

  timeouts {
    create = "60m"
    delete = "60m"
  }

  depends_on = [
    aws_iam_role_policy.bedrock_kb_policy,
    aws_s3vectors_index.basic_rag,
  ]
}

resource "aws_bedrockagent_data_source" "basic_rag" {
  count = var.enable_basic_rag ? 1 : 0

  knowledge_base_id    = aws_bedrockagent_knowledge_base.basic_rag[0].id
  name                 = "${local.name_prefix}-basic-rag-source"
  description          = "Raw synthetic banking PDFs for Basic RAG."
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
      chunking_strategy = "FIXED_SIZE"

      fixed_size_chunking_configuration {
        max_tokens         = var.basic_chunking_max_tokens
        overlap_percentage = var.basic_chunking_overlap_percentage
      }
    }
  }

  timeouts {
    create = "60m"
    delete = "60m"
  }

  depends_on = [
    aws_s3_object.raw_data,
    aws_bedrockagent_knowledge_base.basic_rag,
  ]
}
