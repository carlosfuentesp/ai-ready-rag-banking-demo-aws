from __future__ import annotations

from dataclasses import dataclass


@dataclass
class RetrievalEvaluation:
    recall_at_k: float
    precision_at_k: float
    source_coverage: float
    obsolete_source_count: int
    restricted_source_count: int


def evaluate_retrieval(retrieved_doc_ids: list[str], expected_doc_ids: list[str], restricted_doc_ids: list[str], obsolete_doc_ids: list[str]) -> RetrievalEvaluation:
    retrieved = set(retrieved_doc_ids)
    expected = set(expected_doc_ids)
    restricted = set(restricted_doc_ids)
    obsolete = set(obsolete_doc_ids)

    true_positive = len(retrieved & expected)
    recall = true_positive / max(1, len(expected))
    precision = true_positive / max(1, len(retrieved))
    source_coverage = len(retrieved & expected) / max(1, len(expected))
    return RetrievalEvaluation(
        recall_at_k=recall,
        precision_at_k=precision,
        source_coverage=source_coverage,
        obsolete_source_count=len(retrieved & obsolete),
        restricted_source_count=len(retrieved & restricted),
    )
