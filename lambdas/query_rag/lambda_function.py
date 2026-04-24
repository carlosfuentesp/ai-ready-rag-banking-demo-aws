from __future__ import annotations

import json
import os
import re
from typing import Any

import boto3


agent_runtime = boto3.client("bedrock-agent-runtime")
bedrock_runtime = boto3.client("bedrock-runtime")
dynamodb = boto3.resource("dynamodb")

BASIC_KB_ID = os.environ.get("BASIC_KB_ID", "")
AI_READY_KB_ID = os.environ.get("AI_READY_KB_ID", "")
GENERATION_MODEL_ID = os.environ.get("GENERATION_MODEL_ID", "anthropic.claude-3-haiku-20240307-v1:0")
TRANSACTIONS_TABLE = os.environ.get("TRANSACTIONS_TABLE", "")
PRODUCTS_TABLE = os.environ.get("PRODUCTS_TABLE", "")
CUSTOMERS_TABLE = os.environ.get("CUSTOMERS_TABLE", "")


def response(status_code: int, body: dict[str, Any]) -> dict[str, Any]:
    return {
        "statusCode": status_code,
        "headers": {
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Headers": "content-type",
            "Access-Control-Allow-Methods": "OPTIONS,POST",
            "Content-Type": "application/json",
        },
        "body": json.dumps(body, ensure_ascii=False),
    }


def parse_body(event: dict[str, Any]) -> dict[str, Any]:
    raw = event.get("body") or "{}"
    if event.get("isBase64Encoded"):
        return {}
    if isinstance(raw, dict):
        return raw
    return json.loads(raw)


def find_id(pattern: str, text: str) -> str | None:
    match = re.search(pattern, text, flags=re.IGNORECASE)
    return match.group(0).upper() if match else None


def get_item(table_name: str, key: dict[str, str]) -> dict[str, Any] | None:
    if not table_name:
        return None
    item = dynamodb.Table(table_name).get_item(Key=key).get("Item")
    return dict(item) if item else None


def structured_context(question: str) -> dict[str, Any]:
    transaction_id = find_id(r"\bTX-\d+\b", question)
    customer_id = find_id(r"\bC-\d+\b", question)

    transaction = get_item(TRANSACTIONS_TABLE, {"transaction_id": transaction_id}) if transaction_id else None
    if transaction and not customer_id:
        customer_id = str(transaction.get("customer_id", ""))

    product = None
    if transaction and transaction.get("product_id"):
        product = get_item(PRODUCTS_TABLE, {"product_id": str(transaction["product_id"])})

    customer = get_item(CUSTOMERS_TABLE, {"customer_id": customer_id}) if customer_id else None
    if customer:
        customer = {
            "customer_id": customer.get("customer_id"),
            "segment": customer.get("segment"),
            "risk_level": customer.get("risk_level"),
            "consent_status": customer.get("consent_status"),
        }

    return {
        "transaction": transaction,
        "product": product,
        "customer": customer,
    }


def retrieve(knowledge_base_id: str, question: str) -> list[dict[str, Any]]:
    if not knowledge_base_id:
        return []
    result = agent_runtime.retrieve(
        knowledgeBaseId=knowledge_base_id,
        retrievalQuery={"text": question},
        retrievalConfiguration={
            "vectorSearchConfiguration": {
                "numberOfResults": 8,
            }
        },
    )
    return result.get("retrievalResults", [])


def compact_sources(results: list[dict[str, Any]]) -> list[dict[str, Any]]:
    sources = []
    for result in results[:8]:
        location = result.get("location", {})
        metadata = result.get("metadata", {})
        content = result.get("content", {}).get("text", "")
        sources.append(
            {
                "score": result.get("score"),
                "source": location.get("s3Location", {}).get("uri") or metadata.get("source_path") or "unknown",
                "metadata": metadata,
                "excerpt": content[:700],
            }
        )
    return sources


def build_prompt(mode: str, question: str, sources: list[dict[str, Any]], structured: dict[str, Any]) -> tuple[str, str]:
    context = json.dumps({"sources": sources, "structured_data": structured}, ensure_ascii=False, default=str)
    if mode == "basic":
        system = (
            "Eres el modo Basic RAG de una demo bancaria sintética. Solo puedes usar fragmentos recuperados desde PDFs raw. "
            "No tienes acceso a DynamoDB, knowledge graph, lineage, roles, vigencia confiable ni metadata avanzada. "
            "Si la respuesta requiere validar transacciones, consultar tablas, navegar relaciones de grafo o usar datos no presentes en los fragmentos, dilo claramente. "
            "Si no hay evidencia suficiente, responde que no sabes con la información recuperada. "
            "Muestra brevemente riesgos de la respuesta cuando aplique."
        )
    else:
        system = (
            "Eres el modo AI-Ready GraphRAG + Agent de una demo bancaria sintética. Usa fuentes recuperadas, metadata, relaciones de grafo y datos estructurados. "
            "Filtra mentalmente por producto, país EC, vigencia, rol y confidencialidad. No reveles matriz interna, score de contracargo ni umbral de fraude al cliente. "
            "Si la pregunta está fuera del dominio de reclamos por consumo no reconocido en tarjeta de crédito, responde que no tienes información suficiente. "
            "Si propones crear caso o bloqueo preventivo, indica que requiere confirmación humana y auditoría."
        )
    user = (
        f"Pregunta:\n{question}\n\n"
        f"Contexto JSON recuperado:\n{context}\n\n"
        "Responde en español. Incluye una sección breve de fuentes usadas. No inventes datos."
    )
    return system, user


def generate(system: str, user: str) -> str:
    body = {
        "anthropic_version": "bedrock-2023-05-31",
        "max_tokens": 900,
        "temperature": 0.1,
        "system": system,
        "messages": [
            {
                "role": "user",
                "content": [{"type": "text", "text": user}],
            }
        ],
    }
    result = bedrock_runtime.invoke_model(
        modelId=GENERATION_MODEL_ID,
        body=json.dumps(body),
        accept="application/json",
        contentType="application/json",
    )
    payload = json.loads(result["body"].read())
    return "".join(part.get("text", "") for part in payload.get("content", []) if part.get("type") == "text")


def lambda_handler(event, context):
    if event.get("requestContext", {}).get("http", {}).get("method") == "OPTIONS":
        return response(204, {})

    try:
        body = parse_body(event)
        mode = str(body.get("mode", "basic")).strip().lower()
        question = str(body.get("question", "")).strip()
        if mode not in {"basic", "ai-ready"}:
            return response(400, {"error": "mode must be basic or ai-ready"})
        if not question:
            return response(400, {"error": "question is required"})

        kb_id = BASIC_KB_ID if mode == "basic" else AI_READY_KB_ID
        retrieved = retrieve(kb_id, question)
        sources = compact_sources(retrieved)
        structured = structured_context(question) if mode == "ai-ready" else {}
        system, user = build_prompt(mode, question, sources, structured)
        answer = generate(system, user)
        return response(
            200,
            {
                "mode": mode,
                "answer": answer,
                "sources": sources,
                "structured_data": structured,
                "retrieval_count": len(retrieved),
            },
        )
    except Exception as exc:
        return response(500, {"error": str(exc)})
