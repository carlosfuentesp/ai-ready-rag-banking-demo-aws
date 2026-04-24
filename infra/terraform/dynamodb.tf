resource "aws_dynamodb_table" "tables" {
  for_each = local.dynamodb_tables

  name         = "${local.name_prefix}-${replace(each.key, "_", "-")}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = each.value.hash_key

  attribute {
    name = each.value.hash_key
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }
}
