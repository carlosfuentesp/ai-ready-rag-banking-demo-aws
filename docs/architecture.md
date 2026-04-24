# Architecture

This demo has two implementations:

## Basic RAG

```text
S3 raw PDFs
  → fixed-size chunks
  → vector index
  → retrieve top-k
  → answer
```

Expected failure modes:

- obsolete sources,
- internal source leakage,
- mixed product contexts,
- no transaction validation,
- no lineage,
- unsafe action suggestion.

## AI-Ready GraphRAG + Agent

```text
S3 raw documents
  → extraction / OCR
  → document classification
  → structure-aware chunking
  → semantic chunking
  → entity extraction
  → metadata enrichment
  → embeddings
  → Neptune graph relationships
  → metadata-filtered retrieval
  → Bedrock Guardrails
  → agentic action with confirmation
  → lineage + audit
```

## AWS mapping

| Layer | Service |
|---|---|
| Raw/curated object storage | Amazon S3 |
| Transactional synthetic tables | Amazon DynamoDB |
| Basic vector search | Amazon OpenSearch Serverless |
| Managed RAG | Amazon Bedrock Knowledge Bases |
| GraphRAG | Bedrock Knowledge Bases + Amazon Neptune Analytics |
| Guardrails | Amazon Bedrock Guardrails |
| Agent actions | Amazon Bedrock Agents + AWS Lambda |
| Runtime logs | Amazon CloudWatch |
| Lineage | Amazon DataZone + OpenLineage-compatible curated assets |
| Provisioning | Terraform |

## Why GraphRAG

The banking question needs multiple semantic hops:

```text
TX-991
 → Product: tarjeta_credito
 → ClaimType: consumo_no_reconocido
 → Policy: POL-RECLAMOS-TC-V3
 → Circular: CIRCULAR-PLAZOS-2025
 → Procedure: PROC-ATENCION-CNR
 → Action: bloqueo_preventivo
 → Role: asesor
```

A vector-only search may find semantically similar text, but it does not guarantee relationship traversal, policy supersession, validity filtering, role filtering, or action semantics.
