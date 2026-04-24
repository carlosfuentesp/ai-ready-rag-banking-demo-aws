#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_DIR="$ROOT_DIR/outputs"
AWS_REGION="${AWS_REGION:-us-east-1}"

KB_ID="${KB_ID:-$(jq -r '.knowledgeBase.knowledgeBaseId // .knowledgeBaseId' "$OUT_DIR/bedrock_graphrag_kb.json")}"
DATA_SOURCE_ID="${DATA_SOURCE_ID:-$(jq -r '.dataSource.dataSourceId // .dataSourceId' "$OUT_DIR/bedrock_graphrag_data_source.json")}"

aws bedrock-agent start-ingestion-job \
  --region "$AWS_REGION" \
  --knowledge-base-id "$KB_ID" \
  --data-source-id "$DATA_SOURCE_ID" \
  --output json | tee "$OUT_DIR/bedrock_graphrag_ingestion_job.json"
