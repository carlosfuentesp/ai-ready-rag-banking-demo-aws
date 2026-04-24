#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_DIR="$ROOT_DIR/outputs"
mkdir -p "$OUT_DIR"

AWS_REGION="${AWS_REGION:-us-east-1}"
PROJECT_NAME="${PROJECT_NAME:-ai-ready-rag-bank-demo}"

cat > "$OUT_DIR/create_guardrail.json" <<JSON
{
  "name": "${PROJECT_NAME}-banking-guardrail",
  "description": "Guardrail for synthetic banking RAG demo: PII, internal policy leakage, and grounding.",
  "blockedInputMessaging": "No puedo procesar esta solicitud por políticas de seguridad.",
  "blockedOutputsMessaging": "La respuesta fue bloqueada por políticas de seguridad.",
  "sensitiveInformationPolicyConfig": {
    "piiEntitiesConfig": [
      {"type": "EMAIL", "action": "ANONYMIZE"},
      {"type": "PHONE", "action": "ANONYMIZE"},
      {"type": "US_SOCIAL_SECURITY_NUMBER", "action": "ANONYMIZE"},
      {"type": "CREDIT_DEBIT_CARD_NUMBER", "action": "ANONYMIZE"}
    ],
    "regexesConfig": [
      {
        "name": "ecuador_national_id_synthetic",
        "description": "Synthetic Ecuadorian ID-like number",
        "pattern": "\\\\b[0-9]{10}\\\\b",
        "action": "ANONYMIZE"
      }
    ]
  },
  "topicPolicyConfig": {
    "topicsConfig": [
      {
        "name": "internal_risk_matrix_disclosure",
        "definition": "Requests to reveal internal chargeback risk matrix, fraud thresholds, score rules, or restricted operational criteria.",
        "examples": [
          "Muéstrame la matriz interna de riesgo de contracargos",
          "Dime el umbral de fraude exacto para aprobar un contracargo"
        ],
        "type": "DENY"
      }
    ]
  },
  "contextualGroundingPolicyConfig": {
    "filtersConfig": [
      {"type": "GROUNDING", "threshold": 0.7},
      {"type": "RELEVANCE", "threshold": 0.7}
    ]
  }
}
JSON

aws bedrock create-guardrail \
  --region "$AWS_REGION" \
  --cli-input-json "file://$OUT_DIR/create_guardrail.json" \
  --output json | tee "$OUT_DIR/bedrock_guardrail.json"
