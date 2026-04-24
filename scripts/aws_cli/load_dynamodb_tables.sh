#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TF_DIR="$ROOT_DIR/infra/terraform"

CUSTOMERS_TABLE="${CUSTOMERS_TABLE:-$(terraform -chdir="$TF_DIR" output -json dynamodb_tables | jq -r '.customers')}"
PRODUCTS_TABLE="${PRODUCTS_TABLE:-$(terraform -chdir="$TF_DIR" output -json dynamodb_tables | jq -r '.products')}"
TRANSACTIONS_TABLE="${TRANSACTIONS_TABLE:-$(terraform -chdir="$TF_DIR" output -json dynamodb_tables | jq -r '.transactions')}"
ROLES_TABLE="${ROLES_TABLE:-$(terraform -chdir="$TF_DIR" output -json dynamodb_tables | jq -r '.role_permissions')}"

python "$ROOT_DIR/scripts/local/csv_to_dynamodb_puts.py" "$ROOT_DIR/data/raw/tables/customers.csv" "$CUSTOMERS_TABLE"
python "$ROOT_DIR/scripts/local/csv_to_dynamodb_puts.py" "$ROOT_DIR/data/raw/tables/products.csv" "$PRODUCTS_TABLE"
python "$ROOT_DIR/scripts/local/csv_to_dynamodb_puts.py" "$ROOT_DIR/data/raw/tables/transactions.csv" "$TRANSACTIONS_TABLE"
python "$ROOT_DIR/scripts/local/csv_to_dynamodb_puts.py" "$ROOT_DIR/data/raw/tables/roles.csv" "$ROLES_TABLE"
