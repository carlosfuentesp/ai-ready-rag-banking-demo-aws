from __future__ import annotations

import time
import uuid
from dataclasses import asdict
from pathlib import Path
import json

from .lineage import LineageStore
from .models import AgentAction, UserContext


class BankingAgent:
    def __init__(self, audit_path: str | Path = "data/runtime/audit_events.jsonl", lineage: LineageStore | None = None) -> None:
        self.audit_path = Path(audit_path)
        self.audit_path.parent.mkdir(parents=True, exist_ok=True)
        self.lineage = lineage or LineageStore()

    def propose_create_claim_and_block(self, customer_id: str, transaction_id: str, user: UserContext) -> AgentAction:
        return AgentAction(
            action_id=f"act-{uuid.uuid4().hex[:8]}",
            action_type="CREATE_CLAIM_AND_REQUEST_CARD_BLOCK",
            requires_confirmation=True,
            payload={
                "customer_id": customer_id,
                "transaction_id": transaction_id,
                "requested_by": user.user_id,
                "role": user.role,
            },
        )

    def execute(self, action: AgentAction, confirmed: bool) -> dict:
        if action.requires_confirmation and not confirmed:
            action.status = "waiting_confirmation"
            return {"status": action.status, "message": "La acción requiere confirmación humana."}

        case_id = f"RC-2025-{uuid.uuid4().hex[:6].upper()}"
        audit_event = {
            "audit_id": f"aud-{uuid.uuid4().hex[:10]}",
            "timestamp": int(time.time()),
            "case_id": case_id,
            "action": action.action_type,
            "payload": action.payload,
            "status": "executed",
        }
        with self.audit_path.open("a", encoding="utf-8") as f:
            f.write(json.dumps(audit_event, ensure_ascii=False) + "\n")

        lineage_id = self.lineage.emit(
            "AGENT_ACTION_EXECUTED",
            inputs=[action.action_id, action.payload["transaction_id"]],
            outputs=[case_id, audit_event["audit_id"]],
            metadata=audit_event,
        )
        action.status = "executed"
        return {
            "status": "executed",
            "case_id": case_id,
            "block_request_status": "requested",
            "audit_id": audit_event["audit_id"],
            "lineage_event_id": lineage_id,
        }
