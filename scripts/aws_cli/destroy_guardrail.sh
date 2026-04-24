#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_DIR="$ROOT_DIR/outputs"

AWS_REGION="${AWS_REGION:-us-east-1}"
GUARDRAIL_FILE="$OUT_DIR/bedrock_guardrail.json"

if [[ ! -f "$GUARDRAIL_FILE" ]]; then
  echo "No Bedrock guardrail output file found; nothing to delete."
  exit 0
fi

GUARDRAIL_ID="$(jq -r '.guardrailId // .guardrail.guardrailId // empty' "$GUARDRAIL_FILE")"

if [[ -n "$GUARDRAIL_ID" ]]; then
  echo "Deleting Bedrock guardrail: $GUARDRAIL_ID"
  aws bedrock delete-guardrail \
    --region "$AWS_REGION" \
    --guardrail-identifier "$GUARDRAIL_ID" || true
fi

rm -f "$GUARDRAIL_FILE" "$OUT_DIR/create_guardrail.json"
