data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  name_prefix            = "${var.project_name}-${random_id.suffix.hex}"
  data_root              = abspath("${path.module}/${var.data_root_path}")
  basic_vector_bucket    = substr(replace(lower("${var.project_name}-${random_id.suffix.hex}-basic-vectors"), "_", "-"), 0, 63)
  basic_vector_index     = "basic-rag"
  graphrag_vector_bucket = substr(replace(lower("${var.project_name}-${random_id.suffix.hex}-graphrag-vectors"), "_", "-"), 0, 63)
  graphrag_vector_index  = "graphrag"

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
  }
}
