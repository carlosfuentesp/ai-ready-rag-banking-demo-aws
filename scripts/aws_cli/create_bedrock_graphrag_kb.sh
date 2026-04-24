#!/usr/bin/env bash
set -euo pipefail

# Creates:
# 1. Neptune Analytics graph with vector search.
# 2. Bedrock Knowledge Base with NEPTUNE_ANALYTICS storage.
# 3. S3 data source with context enrichment.
#
# This script is intentionally parameterized because Bedrock/GraphRAG APIs evolve quickly.
# Run it after Terraform creates S3 buckets and IAM roles.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_DIR="$ROOT_DIR/outputs"
mkdir -p "$OUT_DIR"

AWS_REGION="${AWS_REGION:-us-east-1}"
PROJECT_NAME="${PROJECT_NAME:-ai-ready-rag-bank-demo}"
RAW_BUCKET="${RAW_BUCKET:?RAW_BUCKET is required}"
BEDROCK_KB_ROLE_ARN="${BEDROCK_KB_ROLE_ARN:?BEDROCK_KB_ROLE_ARN is required}"
EMBEDDING_MODEL_ARN="${EMBEDDING_MODEL_ARN:-arn:aws:bedrock:${AWS_REGION}::foundation-model/cohere.embed-multilingual-v3}"
GRAPH_ENRICHMENT_MODEL_ARN="${GRAPH_ENRICHMENT_MODEL_ARN:-arn:aws:bedrock:${AWS_REGION}::foundation-model/anthropic.claude-3-haiku-20240307-v1:0}"
NEPTUNE_PROVISIONED_MEMORY="${NEPTUNE_PROVISIONED_MEMORY:-16}"

GRAPH_NAME="$(echo "${PROJECT_NAME}-graph" | tr '[:upper:]_' '[:lower:]-' | cut -c1-63)"
KB_NAME="${PROJECT_NAME}-graphrag-kb"

echo "Creating Neptune Analytics graph: $GRAPH_NAME"
aws neptune-graph create-graph \
  --region "$AWS_REGION" \
  --graph-name "$GRAPH_NAME" \
  --provisioned-memory "$NEPTUNE_PROVISIONED_MEMORY" \
  --vector-search-configuration dimension=1024 \
  --no-public-connectivity \
  --output json > "$OUT_DIR/neptune_graph.json"

GRAPH_ARN="$(jq -r '.arn' "$OUT_DIR/neptune_graph.json")"

cat > "$OUT_DIR/create_kb_graphrag.json" <<JSON
{
  "description": "AI-Ready GraphRAG knowledge base for synthetic banking demo",
  "roleArn": "${BEDROCK_KB_ROLE_ARN}",
  "knowledgeBaseConfiguration": {
    "type": "VECTOR",
    "vectorKnowledgeBaseConfiguration": {
      "embeddingModelArn": "${EMBEDDING_MODEL_ARN}"
    }
  },
  "storageConfiguration": {
    "type": "NEPTUNE_ANALYTICS",
    "neptuneAnalyticsConfiguration": {
      "graphArn": "${GRAPH_ARN}",
      "fieldMapping": {
        "metadataField": "metadata",
        "textField": "text"
      }
    }
  }
}
JSON

echo "Creating Bedrock GraphRAG Knowledge Base"
aws bedrock-agent create-knowledge-base \
  --region "$AWS_REGION" \
  --name "$KB_NAME" \
  --cli-input-json "file://$OUT_DIR/create_kb_graphrag.json" \
  --output json > "$OUT_DIR/bedrock_graphrag_kb.json"

KB_ID="$(jq -r '.knowledgeBase.knowledgeBaseId // .knowledgeBaseId' "$OUT_DIR/bedrock_graphrag_kb.json")"

cat > "$OUT_DIR/create_graphrag_data_source.json" <<JSON
{
  "dataSourceConfiguration": {
    "type": "S3",
    "s3Configuration": {
      "bucketArn": "arn:aws:s3:::${RAW_BUCKET}",
      "inclusionPrefixes": ["raw/documents/"]
    }
  },
  "vectorIngestionConfiguration": {
    "contextEnrichmentConfiguration": {
      "type": "BEDROCK_FOUNDATION_MODEL",
      "bedrockFoundationModelConfiguration": {
        "modelArn": "${GRAPH_ENRICHMENT_MODEL_ARN}",
        "enrichmentStrategyConfiguration": {
          "method": "CHUNK_ENTITY_EXTRACTION"
        }
      }
    }
  }
}
JSON

echo "Creating GraphRAG S3 data source"
aws bedrock-agent create-data-source \
  --region "$AWS_REGION" \
  --knowledge-base-id "$KB_ID" \
  --name "${PROJECT_NAME}-graphrag-source" \
  --description "Synthetic banking documents for GraphRAG" \
  --cli-input-json "file://$OUT_DIR/create_graphrag_data_source.json" \
  --output json > "$OUT_DIR/bedrock_graphrag_data_source.json"

echo "Created GraphRAG resources:"
cat "$OUT_DIR/bedrock_graphrag_kb.json"
cat "$OUT_DIR/bedrock_graphrag_data_source.json"
