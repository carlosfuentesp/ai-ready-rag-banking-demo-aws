#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_DIR="$ROOT_DIR/outputs"

AWS_REGION="${AWS_REGION:-us-east-1}"
KB_FILE="$OUT_DIR/bedrock_graphrag_kb.json"
DATA_SOURCE_FILE="$OUT_DIR/bedrock_graphrag_data_source.json"
GRAPH_FILE="$OUT_DIR/neptune_graph.json"

if [[ -f "$DATA_SOURCE_FILE" && -f "$KB_FILE" ]]; then
  KB_ID="$(jq -r '.knowledgeBase.knowledgeBaseId // .knowledgeBaseId // empty' "$KB_FILE")"
  DATA_SOURCE_ID="$(jq -r '.dataSource.dataSourceId // .dataSourceId // empty' "$DATA_SOURCE_FILE")"
  if [[ -n "$KB_ID" && -n "$DATA_SOURCE_ID" ]]; then
    echo "Deleting Bedrock data source: $DATA_SOURCE_ID"
    aws bedrock-agent delete-data-source \
      --region "$AWS_REGION" \
      --knowledge-base-id "$KB_ID" \
      --data-source-id "$DATA_SOURCE_ID" || true
  fi
fi

if [[ -f "$KB_FILE" ]]; then
  KB_ID="$(jq -r '.knowledgeBase.knowledgeBaseId // .knowledgeBaseId // empty' "$KB_FILE")"
  if [[ -n "$KB_ID" ]]; then
    echo "Deleting Bedrock knowledge base: $KB_ID"
    aws bedrock-agent delete-knowledge-base \
      --region "$AWS_REGION" \
      --knowledge-base-id "$KB_ID" || true
  fi
fi

if [[ -f "$GRAPH_FILE" ]]; then
  GRAPH_ID="$(jq -r '.id // .graphId // empty' "$GRAPH_FILE")"
  GRAPH_ARN="$(jq -r '.arn // empty' "$GRAPH_FILE")"
  GRAPH_IDENTIFIER="${GRAPH_ID:-$GRAPH_ARN}"
  if [[ -n "$GRAPH_IDENTIFIER" ]]; then
    echo "Deleting Neptune Analytics graph: $GRAPH_IDENTIFIER"
    aws neptune-graph delete-graph \
      --region "$AWS_REGION" \
      --graph-identifier "$GRAPH_IDENTIFIER" \
      --skip-snapshot || true
  fi
fi

rm -f "$KB_FILE" "$DATA_SOURCE_FILE" "$GRAPH_FILE" \
  "$OUT_DIR/create_kb_graphrag.json" \
  "$OUT_DIR/create_graphrag_data_source.json" \
  "$OUT_DIR/bedrock_graphrag_ingestion_job.json"
