data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  name_prefix             = "${var.project_name}-${random_id.suffix.hex}"
  data_root               = abspath("${path.module}/${var.data_root_path}")
  basic_vector_bucket     = substr(replace(lower("${var.project_name}-${random_id.suffix.hex}-basic-vectors"), "_", "-"), 0, 63)
  basic_vector_index      = "basic-rag"
  graphrag_neptune_graph  = substr(replace(lower("${var.project_name}-${random_id.suffix.hex}-graphrag"), "_", "-"), 0, 63)
  graph_context_model_arn = "arn:${data.aws_partition.current.partition}:bedrock:${var.aws_region}::foundation-model/${var.graph_context_model_id}"

  raw_files     = fileset(local.data_root, "raw/**/*")
  curated_files = fileset(local.data_root, "curated/**/*")

  dynamodb_tables = {
    customers = {
      hash_key = "customer_id"
    }
    products = {
      hash_key = "product_id"
    }
    transactions = {
      hash_key = "transaction_id"
    }
    claims = {
      hash_key = "case_id"
    }
    audit_events = {
      hash_key = "audit_id"
    }
    role_permissions = {
      hash_key = "role"
    }
    graph_nodes = {
      hash_key = "node_id"
    }
    graph_edges = {
      hash_key = "edge_id"
    }
    lineage_events = {
      hash_key = "event_id"
    }
  }
}
