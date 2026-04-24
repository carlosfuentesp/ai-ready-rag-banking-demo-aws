from __future__ import annotations

import json
import os
import time
import uuid
from typing import Any

import boto3

dynamodb = boto3.resource("dynamodb")
CLAIMS_TABLE = os.environ.get("CLAIMS_TABLE", "ai-ready-demo-claims")
AUDIT_TABLE  = os.environ.get("AUDIT_TABLE",  "ai-ready-demo-audit-events")


def response(status_code: int, body: dict[str, Any]) -> dict[str, Any]:
    return {
        "statusCode": status_code,
        "headers": {
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Headers": "content-type",
            "Access-Control-Allow-Methods": "OPTIONS,POST",
            "Content-Type": "application/json",
        },
        "body": json.dumps(body, ensure_ascii=False),
    }


def parse_body(event: dict[str, Any]) -> dict[str, Any]:
    raw = event.get("body") or "{}"
    if isinstance(raw, dict):
        return raw
    return json.loads(raw)


def lambda_handler(event, context):
    if event.get("requestContext", {}).get("http", {}).get("method") == "OPTIONS":
        return response(204, {})

    try:
        body           = parse_body(event)
        customer_id    = body.get("customer_id")
        transaction_id = body.get("transaction_id")
        requested_by   = body.get("requested_by", "unknown")

        if not customer_id or not transaction_id:
            return response(400, {"error": "customer_id and transaction_id are required"})

        case_id = f"RC-2025-{uuid.uuid4().hex[:8].upper()}"
        now     = int(time.time())

        dynamodb.Table(CLAIMS_TABLE).put_item(Item={
            "case_id":        case_id,
            "customer_id":    customer_id,
            "transaction_id": transaction_id,
            "status":         "created",
            "created_at":     now,
            "requested_by":   requested_by,
        })

        audit_id = f"aud-{uuid.uuid4().hex[:12]}"
        dynamodb.Table(AUDIT_TABLE).put_item(Item={
            "audit_id":       audit_id,
            "timestamp":      now,
            "action":         "CREATE_CLAIM_CASE",
            "case_id":        case_id,
            "customer_id":    customer_id,
            "transaction_id": transaction_id,
            "requested_by":   requested_by,
        })

        return response(200, {"case_id": case_id, "audit_id": audit_id})
    except Exception as exc:
        return response(500, {"error": str(exc)})
