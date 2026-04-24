# AI-Ready RAG Banking Demo on AWS

Demo comparativa para una charla sobre **AI-Ready Data, RAG y agentes** usando un caso sintético de banca ecuatoriana: reclamo por consumo no reconocido en tarjeta de crédito.

El proyecto compara:

1. **RAG común**: PDFs crudos + chunking fijo + vector search.
2. **AI-Ready GraphRAG + Agent**: documentos curados, metadata rica, chunking estructural/semántico/entity-aware, knowledge graph, lineage, permisos, PII masking, guardrails y acciones agentic con confirmación humana.

> Todos los datos son sintéticos. No uses datos reales de clientes, bancos o tarjetas.

## Qué demuestra

- Fallas típicas de una RAG común.
- Data wrangling para GenAI.
- Structure-aware + semantic + entity-aware chunking.
- Metadata para razonamiento.
- Knowledge graph visible y saltos semánticos.
- Data lineage desde PDF hasta respuesta/acción.
- Autorización contextual por rol.
- PII masking.
- Guardrails para contenido interno bancario.
- Acción agentic con confirmación y auditoría.
- Infraestructura aprovisionada con Terraform + AWS CLI.

## Arquitectura

```text
                    ┌────────────────────────────┐
                    │ Streamlit Demo UI          │
                    └──────────────┬─────────────┘
                                   │
        ┌──────────────────────────┴──────────────────────────┐
        │                                                     │
┌───────▼────────┐                                  ┌─────────▼─────────┐
│ Basic RAG      │                                  │ AI-Ready GraphRAG │
│ fixed chunks   │                                  │ graph + metadata  │
└───────┬────────┘                                  └─────────┬─────────┘
        │                                                     │
┌───────▼────────┐                         ┌──────────────────▼──────────────────┐
│ S3 raw PDFs    │                         │ S3 curated docs + metadata + graph  │
└────────────────┘                         └──────────────────┬──────────────────┘
                                                               │
                                      ┌────────────────────────▼──────────────────────┐
                                      │ Bedrock Knowledge Bases / Neptune GraphRAG   │
                                      │ OpenSearch Serverless for Basic RAG          │
                                      └────────────────────────┬──────────────────────┘
                                                               │
          ┌────────────────────────────┬───────────────────────┴───────────────────────┐
          │                            │                                               │
┌─────────▼────────┐        ┌──────────▼──────────┐                         ┌──────────▼───────┐
│ DataZone lineage │        │ Bedrock Guardrails  │                         │ Bedrock Agent    │
│ / local lineage  │        │ PII + grounding     │                         │ Lambda tools     │
└──────────────────┘        └─────────────────────┘                         └──────────────────┘
```

## Prerrequisitos

- Terraform >= 1.6
- AWS CLI v2 configurado
- Python 3.11+
- Acceso a modelos de Amazon Bedrock en la región elegida
- Permisos para S3, IAM, DynamoDB, Lambda, Bedrock, OpenSearch Serverless, DataZone y, opcionalmente, Neptune Analytics/GraphRAG

## Modo local

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

python scripts/generate_synthetic_data.py
streamlit run app/streamlit/app.py
```

## Deploy AWS

```bash
cd infra/terraform
terraform init
terraform apply \
  -var='aws_region=us-east-1' \
  -var='enable_static_demo_site=true' \
  -var='enable_bedrock_guardrail=true' \
  -var='enable_bedrock_cli=true'
```

Guía completa de prueba y limpieza: [docs/aws_full_test.md](docs/aws_full_test.md).

## Nota sobre Terraform + AWS CLI

Terraform aprovisiona recursos base: S3, DynamoDB, Lambda, IAM, OpenSearch Serverless, Guardrail, sitio estático opcional y DataZone opcional. Para funciones que suelen cambiar rápido en Bedrock GraphRAG/Neptune Analytics, este repo incluye scripts AWS CLI invocados desde Terraform con `null_resource`; también hay hooks de destroy para que `terraform destroy` elimine esos recursos.

## Flujo de demo

1. Pregunta del asesor: reclamo por consumo no reconocido.
2. RAG común responde con errores plausibles.
3. AI-Ready GraphRAG responde con contexto vigente y autorizado.
4. UI muestra saltos de knowledge graph.
5. UI muestra lineage desde documento hasta respuesta.
6. Usuario intenta pedir información interna restringida.
7. Guardrails/permisos la bloquean.
8. Usuario pide crear caso y bloquear tarjeta.
9. Agente solicita confirmación.
10. Lambda crea caso sintético y registra auditoría.

## Estructura

```text
data/raw/documents/        PDFs sintéticos
data/raw/tables/           CSVs sintéticos
data/curated/              chunks, metadata, grafo y lineage pre-generados
src/ai_ready_demo/         lógica local de demo
app/streamlit/             UI
infra/terraform/           IaC
scripts/aws_cli/           AWS CLI para Bedrock, DataZone, DynamoDB y S3
lambdas/                   funciones Lambda para acciones agentic
tests/                     tests unitarios
```
