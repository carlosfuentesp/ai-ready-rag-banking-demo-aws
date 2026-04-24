#!/usr/bin/env bash
set -euo pipefail

# This script prepares OpenLineage-compatible event payloads from local lineage JSONL.
# DataZone lineage APIs can vary by rollout/region. Use this script as the integration point.
# Fill DOMAIN_ID from terraform output when DataZone is enabled.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_DIR="$ROOT_DIR/outputs"
mkdir -p "$OUT_DIR"

DOMAIN_ID="${DOMAIN_ID:-}"
if [[ -z "$DOMAIN_ID" ]]; then
  echo "DOMAIN_ID is required. Example: DOMAIN_ID=$(terraform -chdir=infra/terraform output -raw datazone_domain_id)"
  exit 1
fi

python "$ROOT_DIR/scripts/local/lineage_to_openlineage.py" \
  "$ROOT_DIR/data/curated/lineage_events.jsonl" \
  "$OUT_DIR/openlineage_events.jsonl"

echo "OpenLineage-compatible events written to $OUT_DIR/openlineage_events.jsonl"
echo "Submit them to Amazon DataZone lineage API according to the API version enabled in your account/region."
