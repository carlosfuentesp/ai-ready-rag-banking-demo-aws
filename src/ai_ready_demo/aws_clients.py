from __future__ import annotations

from dataclasses import dataclass
from typing import Any


@dataclass
class AwsConfig:
    region_name: str = "us-east-1"


class BedrockClientAdapter:
    def retrieve(self, knowledge_base_id: str, query: str) -> dict[str, Any]:
        raise NotImplementedError("Implement with boto3 bedrock-agent-runtime in production.")


class NeptuneClientAdapter:
    def query_paths(self, graph_identifier: str, query: str) -> list[list[str]]:
        raise NotImplementedError("Implement with Neptune Analytics query endpoint in production.")


class DataZoneLineageAdapter:
    def emit_openlineage_event(self, event: dict[str, Any]) -> None:
        raise NotImplementedError("Implement with a DataZone API client in production.")


class DynamoDbAdapter:
    def get_transaction(self, transaction_id: str) -> dict[str, Any]:
        raise NotImplementedError("Implement with boto3 DynamoDB in production.")
