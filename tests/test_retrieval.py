from pathlib import Path

from ai_ready_demo.models import UserContext
from ai_ready_demo.retrieval import AIReadyGraphRAG, BasicRAG

ROOT = Path(__file__).resolve().parents[1]


def test_basic_rag_returns_warnings():
    rag = BasicRAG(ROOT / "data/curated/chunks_basic.jsonl")
    answer = rag.answer("consumo no reconocido tarjeta crédito TX-991", UserContext("u", "asesor"))
    assert answer.warnings


def test_ai_ready_has_graph_paths():
    rag = AIReadyGraphRAG(
        ROOT / "data/curated/chunks_ai_ready.jsonl",
        ROOT / "data/curated/graph_nodes.jsonl",
        ROOT / "data/curated/graph_edges.jsonl",
    )
    answer = rag.answer("consumo no reconocido tarjeta crédito TX-991", UserContext("u", "asesor"))
    assert answer.graph_paths
