from __future__ import annotations

import re
from typing import Any

CARD_RE = re.compile(r"\b(?:\d[ -]*?){13,19}\b")
EMAIL_RE = re.compile(r"[\w.\-+]+@[\w.\-]+\.\w+")
EC_ID_RE = re.compile(r"\b\d{10}\b")


def mask_pii(text: str) -> str:
    text = CARD_RE.sub("[TARJETA_ENMASCARADA]", text)
    text = EMAIL_RE.sub("[EMAIL_ENMASCARADO]", text)
    text = EC_ID_RE.sub("[ID_ENMASCARADO]", text)
    return text


def is_role_allowed(metadata: dict[str, Any], role: str) -> bool:
    allowed = metadata.get("allowed_roles", [])
    confidentiality = metadata.get("confidentiality", "public")
    if confidentiality == "public":
        return True
    return role in allowed


def filter_by_policy(chunks: list[Any], role: str, today: str = "2026-04-24") -> tuple[list[Any], list[str]]:
    allowed, warnings = [], []
    for chunk in chunks:
        md = chunk.metadata
        if not is_role_allowed(md, role):
            warnings.append(f"Chunk {chunk.chunk_id} excluded by role/confidentiality policy.")
            continue
        if md.get("effective_from") and md["effective_from"] > today:
            warnings.append(f"Chunk {chunk.chunk_id} excluded because it is not effective yet.")
            continue
        if md.get("effective_to") and md["effective_to"] < today:
            warnings.append(f"Chunk {chunk.chunk_id} excluded because it is obsolete.")
            continue
        allowed.append(chunk)
    return allowed, warnings


def redact_internal_content(answer: str, role: str) -> str:
    if role == "cliente":
        blocked_terms = [
            "matriz interna",
            "score de contracargo",
            "riesgo operativo",
            "umbral de fraude",
        ]
        for term in blocked_terms:
            answer = re.sub(term, "[contenido interno no compartible]", answer, flags=re.IGNORECASE)
    return mask_pii(answer)
