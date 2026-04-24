from __future__ import annotations

import os
import time
from typing import Any

import boto3


bedrock_agent = boto3.client("bedrock-agent")

TERMINAL_STATUSES = {"COMPLETE", "FAILED", "STOPPED"}
DEFAULT_WAIT_SECONDS = int(os.environ.get("DEFAULT_WAIT_SECONDS", "840"))


def lambda_handler(event: dict[str, Any], context: Any) -> dict[str, Any]:
    knowledge_base_id = str(event["knowledge_base_id"])
    data_source_id = str(event["data_source_id"])
    wait_seconds = int(event.get("wait_seconds", DEFAULT_WAIT_SECONDS))

    started = bedrock_agent.start_ingestion_job(
        knowledgeBaseId=knowledge_base_id,
        dataSourceId=data_source_id,
    )
    ingestion_job = started["ingestionJob"]
    ingestion_job_id = ingestion_job["ingestionJobId"]
    deadline = time.time() + max(0, min(wait_seconds, DEFAULT_WAIT_SECONDS))

    while time.time() < deadline:
        current = bedrock_agent.get_ingestion_job(
            knowledgeBaseId=knowledge_base_id,
            dataSourceId=data_source_id,
            ingestionJobId=ingestion_job_id,
        )["ingestionJob"]
        status = current["status"]
        if status in TERMINAL_STATUSES:
            if status != "COMPLETE":
                raise RuntimeError(f"Bedrock ingestion job {ingestion_job_id} ended with {status}: {current}")
            return {
                "knowledge_base_id": knowledge_base_id,
                "data_source_id": data_source_id,
                "ingestion_job_id": ingestion_job_id,
                "status": status,
            }
        time.sleep(15)

    return {
        "knowledge_base_id": knowledge_base_id,
        "data_source_id": data_source_id,
        "ingestion_job_id": ingestion_job_id,
        "status": "IN_PROGRESS",
        "message": "Ingestion job is still running after Terraform wait window.",
    }
