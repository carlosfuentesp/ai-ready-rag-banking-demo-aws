# AI-Ready Data Concepts in the Demo

## 1. Data as product

Each document has owner, steward, version, effective dates, confidentiality, and allowed roles.

## 2. Semantic preparation

The same concept can appear as:

- consumo no reconocido,
- transacción no autorizada,
- cargo desconocido,
- contracargo.

The pipeline maps them to `ClaimType: ConsumoNoReconocido`.

## 3. Chunking method

The AI-Ready pipeline uses:

1. Structure-aware chunking.
2. Semantic chunking.
3. Entity-aware chunking.
4. Parent section/document relationships.
5. Graph expansion.

## 4. Metadata as reasoning layer

Metadata used by retrieval:

- product,
- country,
- business domain,
- effective dates,
- confidentiality,
- allowed roles,
- customer visibility,
- version,
- supersession.

## 5. Knowledge graph

The graph captures relationships that vector similarity alone cannot guarantee:

- customer has product,
- transaction initiates claim,
- claim governed by policy,
- policy updated by circular,
- action requires confirmation,
- role can access document.

## 6. Data lineage

Lineage records:

- source document,
- parsing,
- chunking,
- metadata enrichment,
- graph build,
- retrieval,
- response,
- action,
- audit.

## 7. Security

Security is applied:

- before retrieval: metadata filters,
- during retrieval: role and confidentiality,
- after retrieval: PII masking and guardrails,
- before action: confirmation,
- after action: audit log.

## 8. Production readiness

The demo includes:

- modular architecture,
- AWS-only deployment flow,
- Terraform,
- synthetic data,
- lineage and audit artifacts.
