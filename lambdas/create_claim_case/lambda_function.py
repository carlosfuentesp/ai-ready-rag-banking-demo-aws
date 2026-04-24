import json
import os
import time
import uuid

import boto3

dynamodb = boto3.resource("dynamodb")
CLAIMS_TABLE = os.environ.get("CLAIMS_TABLE", "ai-ready-demo-claims")
AUDIT_TABLE = os.environ.get("AUDIT_TABLE", "ai-ready-demo-audit-events")


def lambda_handler(event, context):
    body = event if isinstance(event, dict) else json.loads(event or "{}")
    customer_id = body.get("customer_id")
    transaction_id = body.get("transaction_id")
    requested_by = body.get("requested_by", "unknown")

    if not customer_id or not transaction_id:
        return {"statusCode": 400, "body": json.dumps({"error": "customer_id and transaction_id are required"})}

    case_id = f"RC-2025-{uuid.uuid4().hex[:8].upper()}"
    now = int(time.time())

    claims_table = dynamodb.Table(CLAIMS_TABLE)
    audit_table = dynamodb.Table(AUDIT_TABLE)

    claims_table.put_item(
        Item={
            "case_id": case_id,
            "customer_id": customer_id,
            "transaction_id": transaction_id,
            "status": "created",
            "created_at": now,
            "requested_by": requested_by,
        }
    )

    audit_id = f"aud-{uuid.uuid4().hex[:12]}"
    audit_table.put_item(
        Item={
            "audit_id": audit_id,
            "timestamp": now,
            "action": "CREATE_CLAIM_CASE",
            "case_id": case_id,
            "customer_id": customer_id,
            "transaction_id": transaction_id,
            "requested_by": requested_by,
        }
    )

    return {"statusCode": 200, "body": json.dumps({"case_id": case_id, "audit_id": audit_id})}
