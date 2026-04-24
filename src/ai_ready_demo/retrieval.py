from __future__ import annotations

import json
import math
import re
from collections import Counter
from pathlib import Path
from typing import Iterable

from .graph import KnowledgeGraph
from .lineage import LineageStore
from .models import Answer, Chunk, RetrievalResult, UserContext
from .security import filter_by_policy, redact_internal_content


def tokenize(text: str) -> list[str]:
    return re.findall(r"[a-záéíóúñ0-9_]+", text.lower())


def load_chunks(path: str | Path) -> list[Chunk]:
    chunks = []
    for line in Path(path).read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        item = json.loads(line)
        chunks.append(
            Chunk(
                chunk_id=item["chunk_id"],
                document_id=item["document_id"],
                parent_section_id=item["parent_section_id"],
                title=item["title"],
                text=item["text"],
                source_page=item["source_page"],
                metadata=item["metadata"],
                entities=item.get("entities", []),
            )
        )
    return chunks


class LocalRetriever:
    def __init__(self, chunks: list[Chunk]) -> None:
        self.chunks = chunks
        self.doc_freq: Counter[str] = Counter()
        for chunk in chunks:
            for token in set(tokenize(chunk.text + " " + chunk.title)):
                self.doc_freq[token] += 1

    def score(self, query: str, chunk: Chunk) -> float:
        q = tokenize(query)
        c = Counter(tokenize(chunk.text + " " + chunk.title + " " + " ".join(chunk.entities)))
        if not q:
            return 0.0
        score = 0.0
        n = len(self.chunks)
        for token in q:
            if token in c:
                idf = math.log((n + 1) / (self.doc_freq[token] + 1)) + 1
                score += c[token] * idf
        return score / (1 + len(c))

    def retrieve(self, query: str, top_k: int = 5) -> list[RetrievalResult]:
        scored = [(self.score(query, c), c) for c in self.chunks]
        scored.sort(reverse=True, key=lambda x: x[0])
        return [
            RetrievalResult(chunk=chunk, score=score, reason="lexical/local vector mock")
            for score, chunk in scored[:top_k]
        ]


class BasicRAG:
    def __init__(self, chunks_path: str | Path, lineage: LineageStore | None = None) -> None:
        self.chunks = load_chunks(chunks_path)
        self.retriever = LocalRetriever(self.chunks)
        self.lineage = lineage or LineageStore()

    def answer(self, query: str, user: UserContext) -> Answer:
        results = self.retriever.retrieve(query, top_k=5)
        event_id = self.lineage.emit(
            "BASIC_RAG_RETRIEVE",
            inputs=[r.chunk.chunk_id for r in results],
            outputs=["basic_answer"],
            metadata={"query": query, "role": user.role},
        )
        text = (
            "Respuesta RAG común: con base en los documentos encontrados, el asesor debería abrir un reclamo, "
            "bloquear la tarjeta y explicar al cliente los criterios internos de contracargo. "
            "Puede usar el tarifario y política recuperados para definir plazos. "
            "Advertencia: esta respuesta es deliberadamente vulnerable para la demo."
        )
        return Answer(
            answer=text,
            sources=results,
            graph_paths=[],
            lineage_event_ids=[event_id],
            warnings=[
                "No se aplicaron filtros de vigencia.",
                "No se aplicaron permisos por rol.",
                "No se validaron datos transaccionales.",
                "No se consultó grafo semántico.",
            ],
        )


class AIReadyGraphRAG:
    def __init__(
        self,
        chunks_path: str | Path,
        nodes_path: str | Path,
        edges_path: str | Path,
        lineage: LineageStore | None = None,
    ) -> None:
        self.chunks = load_chunks(chunks_path)
        self.retriever = LocalRetriever(self.chunks)
        self.kg = KnowledgeGraph.from_jsonl(nodes_path, edges_path)
        self.lineage = lineage or LineageStore()

    def answer(self, query: str, user: UserContext) -> Answer:
        filtered_chunks, warnings = filter_by_policy(self.chunks, user.role)
        retriever = LocalRetriever(filtered_chunks)
        results = retriever.retrieve(query, top_k=6)

        graph_paths = self.kg.semantic_paths(["TX-991", "consumo_no_reconocido", "tarjeta_credito"])
        path_terms = {node.lower() for path in graph_paths for node in path}
        for r in results:
            matches = [node for node in path_terms if any(e in node for e in r.chunk.entities)]
            if matches:
                r.reason = "metadata + graph-expanded retrieval"
                r.graph_path = graph_paths[0] if graph_paths else []

        event_id = self.lineage.emit(
            "AI_READY_GRAPHRAG_RETRIEVE",
            inputs=[r.chunk.chunk_id for r in results] + [n for path in graph_paths for n in path],
            outputs=["ai_ready_answer"],
            metadata={"query": query, "role": user.role, "graph_paths": graph_paths},
        )

        answer = (
            "Respuesta AI-Ready GraphRAG: el consumo TX-991 corresponde a tarjeta de crédito y está asociado "
            "al flujo de consumo no reconocido. La política vigente aplicable es POL-RECLAMOS-TC-V3, actualizada "
            "por la Circular de Plazos 2025. El asesor puede comunicar al cliente el procedimiento general, "
            "solicitar el formulario de reclamo y explicar que se puede gestionar un bloqueo preventivo. "
            "No debe compartir la matriz interna de riesgo ni criterios operativos restringidos. "
            "Para crear el caso o solicitar bloqueo preventivo se requiere confirmación humana."
        )
        answer = redact_internal_content(answer, user.role)
        return Answer(
            answer=answer,
            sources=results,
            graph_paths=graph_paths,
            lineage_event_ids=[event_id],
            warnings=warnings,
        )
