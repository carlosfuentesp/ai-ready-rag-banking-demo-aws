from __future__ import annotations

import json
import os
import time
import uuid
from typing import Any

import boto3

dynamodb = boto3.resource("dynamodb")
AUDIT_TABLE = os.environ.get("AUDIT_TABLE", "ai-ready-demo-audit-events")


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
        body               = parse_body(event)
        customer_id        = body.get("customer_id")
        product_id         = body.get("product_id", "P-TC-001")
        requested_by       = body.get("requested_by", "unknown")
        confirmation_token = body.get("confirmation_token")

        if not customer_id or not confirmation_token:
            return response(400, {"error": "customer_id and confirmation_token are required"})

        audit_id = f"aud-{uuid.uuid4().hex[:12]}"
        dynamodb.Table(AUDIT_TABLE).put_item(Item={
            "audit_id":        audit_id,
            "timestamp":       int(time.time()),
            "action":          "REQUEST_CARD_BLOCK",
            "customer_id":     customer_id,
            "product_id":      product_id,
            "requested_by":    requested_by,
            "status":          "requested",
            "idempotency_key": f"{customer_id}#{product_id}#preventive-block",
        })

        return response(200, {"block_request_status": "requested", "audit_id": audit_id})
    except Exception as exc:
        return response(500, {"error": str(exc)})
