# Codex Project Instructions

Build and maintain a robust AWS demo that compares Basic RAG against AI-Ready GraphRAG + Agent for a synthetic Ecuadorian banking claim scenario.

## Non-negotiables

- Use only synthetic data.
- Never include real customer, bank, card, credential, or account data.
- This demo is AWS-only; do not add local runtime demo paths or local mock test flows.
- Terraform is the source of truth for provisioning.
- Provisioning must be implemented with Terraform resources, not CLI scripts.
- Every module should be small, testable, and documented.
- The demo UI must show Basic RAG and AI-Ready RAG side by side.

## Required concepts to demonstrate

1. Basic RAG failure modes.
2. AI-ready ingestion and preparation.
3. Structure-aware, semantic, entity-aware chunking.
4. Metadata-rich retrieval.
5. Knowledge graph traversal.
6. Data lineage.
7. Role-based contextual authorization.
8. PII masking.
9. Guardrails for internal banking content.
10. Agentic actions with human confirmation and audit logs.
11. Retrieval evaluation.
12. Cost/latency observability hooks.

## Development style

- Prefer Python 3.11.
- Use type hints.
- Keep providers abstract: Bedrock, Neptune, DataZone, DynamoDB, S3.
- AWS credentials are required only when Terraform is applied; static assets and synthetic data generation remain offline build steps.
- Do not hard-code AWS account IDs or ARNs.
- Do not commit `.terraform`, `.venv`, secrets, generated state, or credentials.

## Demo scenario

Synthetic Ecuadorian banking case:

A customer reports an unrecognized USD 326.40 credit-card transaction. The advisor must determine the procedure, customer-facing message, required documents, whether preventive blocking is allowed, and whether a claim case should be opened.

## Expected failure modes in Basic RAG

- Uses obsolete policy.
- Mixes credit-card and savings-account policy.
- Exposes internal matrix content.
- Ignores validity dates.
- Ignores role-based access.
- Does not validate transaction.
- Does not show lineage.
- Recommends unsafe action without confirmation.

## Expected AI-Ready behavior

- Uses current policy and circular.
- Filters by product, country, date, role, and confidentiality.
- Traverses graph relationships.
- Validates transaction in structured data.
- Separates customer-facing and advisor-only content.
- Masks PII.
- Requests confirmation before Lambda action.
- Emits audit and lineage events.
