locals {
  customers_seed    = csvdecode(file("${local.data_root}/raw/tables/customers.csv"))
  products_seed     = csvdecode(file("${local.data_root}/raw/tables/products.csv"))
  transactions_seed = csvdecode(file("${local.data_root}/raw/tables/transactions.csv"))
  roles_seed        = csvdecode(file("${local.data_root}/raw/tables/roles.csv"))

  role_permissions_seed = {
    for row in local.roles_seed : row.role => {
      role                  = row.role
      can_access_public     = row.can_access_public
      can_access_internal   = row.can_access_internal
      can_access_restricted = row.can_access_restricted
      can_execute_action    = row.can_execute_action
    }
  }
}

resource "aws_dynamodb_table_item" "customers" {
  for_each   = var.seed_dynamodb_tables ? { for row in local.customers_seed : row.customer_id => row } : {}
  table_name = aws_dynamodb_table.tables["customers"].name
  hash_key   = aws_dynamodb_table.tables["customers"].hash_key

  item = jsonencode({
    customer_id    = { S = each.value.customer_id }
    name           = { S = each.value.name }
    segment        = { S = each.value.segment }
    risk_level     = { S = each.value.risk_level }
    consent_status = { S = each.value.consent_status }
    email          = { S = each.value.email }
    national_id    = { S = each.value.national_id }
  })
}

resource "aws_dynamodb_table_item" "products" {
  for_each   = var.seed_dynamodb_tables ? { for row in local.products_seed : row.product_id => row } : {}
  table_name = aws_dynamodb_table.tables["products"].name
  hash_key   = aws_dynamodb_table.tables["products"].hash_key

  item = jsonencode({
    product_id   = { S = each.value.product_id }
    customer_id  = { S = each.value.customer_id }
    product_type = { S = each.value.product_type }
    product_name = { S = each.value.product_name }
    status       = { S = each.value.status }
  })
}

resource "aws_dynamodb_table_item" "transactions" {
  for_each   = var.seed_dynamodb_tables ? { for row in local.transactions_seed : row.transaction_id => row } : {}
  table_name = aws_dynamodb_table.tables["transactions"].name
  hash_key   = aws_dynamodb_table.tables["transactions"].hash_key

  item = jsonencode({
    transaction_id = { S = each.value.transaction_id }
    customer_id    = { S = each.value.customer_id }
    product_id     = { S = each.value.product_id }
    product        = { S = each.value.product }
    amount         = { N = each.value.amount }
    merchant       = { S = each.value.merchant }
    city           = { S = each.value.city }
    date           = { S = each.value.date }
    channel        = { S = each.value.channel }
    status         = { S = each.value.status }
  })
}

resource "aws_dynamodb_table_item" "role_permissions" {
  for_each   = var.seed_dynamodb_tables ? local.role_permissions_seed : {}
  table_name = aws_dynamodb_table.tables["role_permissions"].name
  hash_key   = aws_dynamodb_table.tables["role_permissions"].hash_key

  item = jsonencode({
    role                  = { S = each.value.role }
    can_access_public     = { BOOL = each.value.can_access_public == "true" }
    can_access_internal   = { BOOL = each.value.can_access_internal == "true" }
    can_access_restricted = { BOOL = each.value.can_access_restricted == "true" }
    can_execute_action    = { BOOL = each.value.can_execute_action == "true" }
  })
}
