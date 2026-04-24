import json
import os
import time
import uuid

import boto3

dynamodb = boto3.resource("dynamodb")
AUDIT_TABLE = os.environ.get("AUDIT_TABLE", "ai-ready-demo-audit-events")


def lambda_handler(event, context):
    body = event if isinstance(event, dict) else json.loads(event or "{}")
    customer_id = body.get("customer_id")
    product_id = body.get("product_id", "P-TC-001")
    requested_by = body.get("requested_by", "unknown")
    confirmation_token = body.get("confirmation_token")

    if not customer_id or not confirmation_token:
        return {"statusCode": 400, "body": json.dumps({"error": "customer_id and confirmation_token are required"})}

    audit_id = f"aud-{uuid.uuid4().hex[:12]}"
    now = int(time.time())
    audit_table = dynamodb.Table(AUDIT_TABLE)
    audit_table.put_item(
        Item={
            "audit_id": audit_id,
            "timestamp": now,
            "action": "REQUEST_CARD_BLOCK",
            "customer_id": customer_id,
            "product_id": product_id,
            "requested_by": requested_by,
            "status": "requested",
            "idempotency_key": f"{customer_id}#{product_id}#preventive-block",
        }
    )

    return {"statusCode": 200, "body": json.dumps({"block_request_status": "requested", "audit_id": audit_id})}
