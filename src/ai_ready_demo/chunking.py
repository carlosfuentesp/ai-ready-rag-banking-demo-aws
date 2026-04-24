from __future__ import annotations

import hashlib
import re
from pathlib import Path
from typing import Any

from .models import Chunk


SECTION_RE = re.compile(r"^(#+|\d+\.|Artículo|Sección|Cláusula|Tabla)\s+", re.IGNORECASE)


def stable_id(prefix: str, text: str) -> str:
    return f"{prefix}-{hashlib.sha1(text.encode('utf-8')).hexdigest()[:10]}"


def split_sections(text: str) -> list[tuple[str, str]]:
    sections: list[tuple[str, str]] = []
    current_title = "Introducción"
    current_lines: list[str] = []
    for line in text.splitlines():
        clean = line.strip()
        if not clean:
            continue
        if SECTION_RE.match(clean) and current_lines:
            sections.append((current_title, "\n".join(current_lines)))
            current_title = clean
            current_lines = []
        elif SECTION_RE.match(clean):
            current_title = clean
        else:
            current_lines.append(clean)
    if current_lines:
        sections.append((current_title, "\n".join(current_lines)))
    return sections


def semantic_split(section_text: str, max_chars: int = 900) -> list[str]:
    sentences = re.split(r"(?<=[.!?])\s+", section_text)
    chunks, buf = [], ""
    for sentence in sentences:
        if len(buf) + len(sentence) > max_chars and buf:
            chunks.append(buf.strip())
            buf = sentence
        else:
            buf = f"{buf} {sentence}".strip()
    if buf:
        chunks.append(buf.strip())
    return chunks


ENTITY_PATTERNS = {
    "tarjeta_credito": r"tarjeta de crédito|tarjeta credito|visa gold",
    "cuenta_ahorros": r"cuenta de ahorros|cuenta ahorro",
    "consumo_no_reconocido": r"consumo no reconocido|transacción no autorizada|cargo desconocido|contracargo",
    "bloqueo_preventivo": r"bloqueo preventivo|bloquear tarjeta",
    "formulario_reclamo": r"formulario de reclamo",
    "circular_plazos_2025": r"circular.*2025|plazos.*2025",
    "matriz_riesgo": r"matriz.*riesgo|score de contracargo|umbral de fraude",
}


def extract_entities(text: str) -> list[str]:
    found = []
    for entity, pattern in ENTITY_PATTERNS.items():
        if re.search(pattern, text, flags=re.IGNORECASE):
            found.append(entity)
    return found


def build_chunks(document_id: str, raw_text: str, metadata: dict[str, Any], source_page: int = 1) -> list[Chunk]:
    chunks: list[Chunk] = []
    for section_title, body in split_sections(raw_text):
        section_id = stable_id("SEC", f"{document_id}:{section_title}")
        for i, text in enumerate(semantic_split(body)):
            chunk_id = stable_id("CHK", f"{document_id}:{section_id}:{i}:{text}")
            entities = extract_entities(f"{section_title}\n{text}")
            chunk_metadata = dict(metadata)
            chunk_metadata["section_title"] = section_title
            chunk_metadata["entities"] = entities
            chunks.append(
                Chunk(
                    chunk_id=chunk_id,
                    document_id=document_id,
                    parent_section_id=section_id,
                    title=section_title,
                    text=text,
                    source_page=source_page,
                    metadata=chunk_metadata,
                    entities=entities,
                )
            )
    return chunks
