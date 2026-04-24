from __future__ import annotations

import json
import sys
from pathlib import Path

import pandas as pd
import streamlit as st

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "src"))

from ai_ready_demo.agent import BankingAgent
from ai_ready_demo.lineage import LineageStore
from ai_ready_demo.models import UserContext
from ai_ready_demo.retrieval import AIReadyGraphRAG, BasicRAG


st.set_page_config(page_title="AI-Ready RAG Banking Demo", layout="wide")

st.title("AI-Ready Data Demo: RAG común vs AI-Ready GraphRAG + Agent")
st.caption("Caso sintético de banca ecuatoriana: consumo no reconocido en tarjeta de crédito.")


def read_jsonl(path: Path) -> list[dict]:
    if not path.exists():
        return []
    return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]


def render_sources(results):
    rows = []
    for r in results:
        rows.append(
            {
                "score": round(r.score, 4),
                "chunk": r.chunk.chunk_id,
                "document": r.chunk.document_id,
                "section": r.chunk.title,
                "confidentiality": r.chunk.metadata.get("confidentiality"),
                "effective_to": r.chunk.metadata.get("effective_to"),
                "reason": r.reason,
            }
        )
    st.dataframe(pd.DataFrame(rows), use_container_width=True)


def render_graph_paths(paths):
    if not paths:
        st.info("No graph path found.")
        return
    for i, path in enumerate(paths[:5], start=1):
        st.markdown(f"**Path {i}**")
        st.code("  →  ".join(path), language="text")


def render_lineage(event_ids):
    events = read_jsonl(ROOT / "data/runtime/lineage_events.jsonl")
    selected = [e for e in events if e.get("event_id") in set(event_ids)]
    if not selected:
        st.info("No runtime lineage events yet.")
        return
    for e in selected:
        st.json(e, expanded=False)


with st.sidebar:
    st.header("Contexto")
    role = st.selectbox("Rol", ["asesor", "cliente", "supervisor"])
    user = UserContext(user_id=f"demo-{role}", role=role, customer_id="C-1023")
    st.markdown("### Preguntas demo")
    default_query = "El cliente C-1023 reporta el consumo no reconocido TX-991 por USD 326.40 en tarjeta de crédito. ¿Qué debe hacer el asesor, qué puede decir al cliente y si debe bloquear preventivamente la tarjeta?"
    query = st.text_area("Pregunta", default_query, height=160)
    run = st.button("Comparar RAGs", type="primary")

lineage = LineageStore(ROOT / "data/runtime/lineage_events.jsonl")
basic = BasicRAG(ROOT / "data/curated/chunks_basic.jsonl", lineage=lineage)
ai_ready = AIReadyGraphRAG(
    ROOT / "data/curated/chunks_ai_ready.jsonl",
    ROOT / "data/curated/graph_nodes.jsonl",
    ROOT / "data/curated/graph_edges.jsonl",
    lineage=lineage,
)

if run:
    basic_answer = basic.answer(query, user)
    ai_answer = ai_ready.answer(query, user)

    col1, col2 = st.columns(2)
    with col1:
        st.subheader("RAG común")
        st.warning("Diseñada para mostrar fallas plausibles.")
        st.write(basic_answer.answer)
        if basic_answer.warnings:
            st.markdown("**Fallas detectadas**")
            for w in basic_answer.warnings:
                st.error(w)
        st.markdown("**Fuentes recuperadas**")
        render_sources(basic_answer.sources)

    with col2:
        st.subheader("AI-Ready GraphRAG")
        st.success("Retrieval gobernado por metadata, grafo y permisos.")
        st.write(ai_answer.answer)
        if ai_answer.warnings:
            st.markdown("**Filtros aplicados**")
            for w in ai_answer.warnings:
                st.info(w)
        st.markdown("**Fuentes recuperadas**")
        render_sources(ai_answer.sources)

    st.divider()
    gcol, lcol = st.columns(2)
    with gcol:
        st.subheader("Knowledge graph traversal")
        render_graph_paths(ai_answer.graph_paths)

    with lcol:
        st.subheader("Data lineage runtime")
        render_lineage(ai_answer.lineage_event_ids)

    st.divider()
    st.subheader("Acción agentic controlada")
    agent = BankingAgent(ROOT / "data/runtime/audit_events.jsonl", lineage=lineage)
    proposed = agent.propose_create_claim_and_block("C-1023", "TX-991", user)
    st.json(proposed.__dict__)
    confirm = st.checkbox("Confirmo crear el caso y solicitar bloqueo preventivo")
    if st.button("Ejecutar acción"):
        result = agent.execute(proposed, confirmed=confirm)
        st.json(result)
else:
    st.info("Selecciona un rol y ejecuta la comparación.")
    st.markdown("La demo local usa mocks para practicar sin AWS. El deploy AWS usa Terraform y scripts AWS CLI.")
