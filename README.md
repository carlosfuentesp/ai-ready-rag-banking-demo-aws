# AI-Ready RAG Banking Demo on AWS

Demo comparativa para una charla sobre **AI-Ready Data, RAG y agentes** usando un caso sintético de banca ecuatoriana: reclamo por consumo no reconocido en tarjeta de crédito.

El proyecto compara:

1. **RAG común**: PDFs crudos + chunking fijo + vector search.
2. **AI-Ready GraphRAG + Agent**: Bedrock Knowledge Bases GraphRAG sobre Neptune Analytics, metadata rica, chunking semántico/entity-aware, lineage, permisos, PII masking, guardrails y acciones agentic con confirmación humana.

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
- Infraestructura aprovisionada completamente con Terraform.

## Arquitectura

```text
                    ┌────────────────────────────┐
                    │ S3 Static Demo UI          │
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
                                      │ Bedrock KBs / S3 Vectors / Neptune Analytics │
                                      │ API Gateway + Lambda query runtime           │
                                      └────────────────────────┬──────────────────────┘
                                                               │
          ┌────────────────────────────┬───────────────────────┴───────────────────────┐
          │                            │                                               │
┌─────────▼────────┐        ┌──────────▼──────────┐                         ┌──────────▼───────┐
│ DataZone lineage │        │ Bedrock Guardrails  │                         │ Bedrock Agent    │
│ / lineage assets │        │ PII + grounding     │                         │ Lambda tools     │
└──────────────────┘        └─────────────────────┘                         └──────────────────┘
```

## Prerrequisitos

- Terraform >= 1.6
- Credenciales AWS disponibles para Terraform
- Python 3.11+
- Acceso a modelos de Amazon Bedrock en la región elegida
- Permisos para S3, IAM, DynamoDB, Lambda, Bedrock, DataZone y Neptune Analytics/GraphRAG

## Preparar datos sintéticos

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

python scripts/generate_synthetic_data.py
```

## Probar en AWS

```bash
cd infra/terraform
terraform init
terraform apply
```

Cuando termines la prueba, destruye todos los recursos desde `infra/terraform`:

```bash
terraform destroy
```

Los defaults están configurados para desplegar la demo completa en `us-east-1`: sitio estático, Basic RAG, AI-Ready GraphRAG sobre Neptune Analytics, guardrail, datos sintéticos en DynamoDB e ingestion jobs administrados por Terraform. GraphRAG usa Amazon Nova Lite para extracción de entidades durante ingestion, evitando modelos legacy de Anthropic.

El sitio estático publica tres vistas:

- `Comparación`: pregunta única, Basic RAG y AI-Ready RAG lado a lado, semáforo, mapa de grafo y acciones auditadas.
- `RAG Común`: pregunta editable contra la Knowledge Base básica.
- `AI-Ready RAG`: pregunta editable contra GraphRAG + DynamoDB + lineage.

## Nota sobre Terraform

Terraform aprovisiona S3, DynamoDB, Lambda, API Gateway, IAM, S3 Vectors para Basic RAG, Bedrock Guardrail, Bedrock Knowledge Bases, Neptune Analytics para GraphRAG, sitio estático opcional y DataZone opcional. Terraform también invoca una Lambda administrada por Terraform para iniciar los ingestion jobs de Bedrock, sin AWS CLI ni scripts locales.

## Flujo de demo

1. Abre el output `static_demo_site_url`.
2. Ingresa con `carlos.andrade` / `demo123`.
3. En `Comparación`, ejecuta una pregunta y muestra que Basic RAG y AI-Ready RAG responden distinto.
4. Explica el semáforo: AI-Ready valida transacción, producto, lineage, PII y acción auditada.
5. Muestra el mapa: cliente -> producto -> transacción -> reclamo -> política/circular -> acción.
6. Ejecuta una acción agentic con confirmación humana: crear caso o solicitar bloqueo.
7. Cierra con `terraform destroy` para eliminar recursos.

## Preguntas recomendadas

### Reclamo + bloqueo preventivo

```text
No reconozco el cargo TX-991 por USD 326.40 de ECOMMERCE_X en mi tarjeta de crédito. ¿El banco puede abrir un reclamo y bloquear preventivamente la tarjeta? Indica qué documentos necesito, qué mensaje puedo dar al cliente y qué parte requiere confirmación humana.
```

### Política incorrecta

```text
Tengo una tarjeta de crédito, pero también vi una política de reclamos de cuenta de ahorros. Para el cargo TX-991, ¿debo seguir el procedimiento de cuenta de ahorros o el de tarjeta de crédito? Explica con fuentes vigentes.
```

### Contenido restringido

```text
Para decidir si apruebo el reclamo TX-991, muéstrame la matriz interna de riesgo, el score de contracargo y el umbral exacto de fraude que usa el banco.
```

## Costo esperado para demo

Estimación para `us-east-1`, recursos encendidos durante 1 hora y ejecución de las 3 preguntas desde la pantalla comparativa:

| Componente | Estimación |
| --- | ---: |
| Neptune Analytics GraphRAG, 16 m-NCU | ~USD 0.48/h |
| Bedrock generación, 6 respuestas RAG | ~USD 0.02-0.10 |
| Bedrock embeddings + ingestion de pocos PDFs sintéticos | < USD 0.01 |
| Bedrock Guardrails sobre 3 preguntas | < USD 0.01 |
| S3, S3 Vectors, DynamoDB, Lambda, API Gateway, CloudWatch | < USD 0.01 |
| **Total aproximado por 1 hora de demo** | **~USD 0.55-0.70** |

El costo dominante es Neptune Analytics mientras el grafo está encendido. Para evitar cargos fuera del demo, ejecuta `terraform destroy` apenas termines.

## Limpieza AWS

Después de `terraform destroy`, verifica que no queden recursos huérfanos:

```bash
aws resourcegroupstaggingapi get-resources \
  --region us-east-1 \
  --tag-filters Key=Project,Values=ai-ready-rag-bank
```

También conviene revisar CloudWatch Logs, porque los log groups pueden quedar fuera del lifecycle de algunos destroys:

```bash
aws logs describe-log-groups \
  --region us-east-1 \
  --log-group-name-prefix /aws/lambda/ai-ready-rag-bank
```

## Estructura

```text
data/raw/documents/        PDFs sintéticos
data/raw/tables/           CSVs sintéticos
data/curated/              chunks, metadata, grafo y lineage pre-generados
app/static/                UI estática publicada en S3 por Terraform
infra/terraform/           IaC
lambdas/                   funciones Lambda para acciones agentic
scripts/                   generación de datos sintéticos
```
