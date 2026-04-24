#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

RAW_BUCKET="${RAW_BUCKET:-}"
CURATED_BUCKET="${CURATED_BUCKET:-}"

if [[ -z "$RAW_BUCKET" || -z "$CURATED_BUCKET" ]]; then
  echo "Set RAW_BUCKET and CURATED_BUCKET env vars or read them from terraform output."
  exit 1
fi

aws s3 sync "$ROOT_DIR/data/raw" "s3://${RAW_BUCKET}/raw"
aws s3 sync "$ROOT_DIR/data/curated" "s3://${CURATED_BUCKET}/curated"
echo "Data synchronized."
