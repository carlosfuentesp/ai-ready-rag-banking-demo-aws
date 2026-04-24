from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass
class DocumentMetadata:
    document_id: str
    title: str
    doc_type: str
    product: str
    country: str
    business_domain: str
    owner: str
    data_steward: str
    effective_from: str
    effective_to: str
    version: str
    supersedes: str | None
    confidentiality: str
    allowed_roles: list[str]
    customer_visible: bool
    source_path: str


@dataclass
class Chunk:
    chunk_id: str
    document_id: str
    parent_section_id: str
    title: str
    text: str
    source_page: int
    metadata: dict[str, Any]
    entities: list[str] = field(default_factory=list)


@dataclass
class RetrievalResult:
    chunk: Chunk
    score: float
    reason: str
    graph_path: list[str] = field(default_factory=list)


@dataclass
class UserContext:
    user_id: str
    role: str
    customer_id: str | None = None
    locale: str = "es-EC"


@dataclass
class Answer:
    answer: str
    sources: list[RetrievalResult]
    graph_paths: list[list[str]]
    lineage_event_ids: list[str]
    warnings: list[str] = field(default_factory=list)


@dataclass
class AgentAction:
    action_id: str
    action_type: str
    requires_confirmation: bool
    payload: dict[str, Any]
    status: str = "proposed"
