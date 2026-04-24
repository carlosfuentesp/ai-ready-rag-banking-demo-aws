data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  name_prefix = "${var.project_name}-${random_id.suffix.hex}"
  data_root   = abspath("${path.module}/${var.local_data_root}")

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
