# AWS Full Test Runbook

This runbook deploys the synthetic banking RAG demo to AWS with Terraform-managed lifecycle. Use a sandbox AWS account and destroy the stack when finished.

## What Terraform Creates

- S3 buckets for raw, curated, and optional static demo UI assets.
- DynamoDB tables and synthetic seed items.
- Lambda functions for query, claim creation, and preventive card block request.
- API Gateway endpoint used by the static pages for real RAG calls.
- OpenSearch Serverless vector collection.
- Basic RAG Knowledge Base with fixed-size chunking over raw PDFs and S3 Vectors storage.
- Bedrock Guardrail.
- Optional Bedrock GraphRAG Knowledge Base and Neptune Analytics graph.
- Optional DataZone domain.

All persistent AWS resources are managed by Terraform provider resources.

## Prerequisites

- AWS credentials available to Terraform through your normal provider chain, such as environment variables, SSO-backed profile, or an instance/role credential source.
- Terraform >= 1.6.
- Python 3.11+.
- Bedrock model access enabled in the target region.
- IAM permission for S3, DynamoDB, Lambda, IAM, OpenSearch Serverless, Bedrock, Neptune Analytics, and optionally DataZone.

## Prepare Data

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python scripts/generate_synthetic_data.py
```

## Deploy

```bash
cd infra/terraform
terraform init
terraform apply \
  -var='aws_region=us-east-1' \
  -var='enable_static_demo_site=true' \
  -var='enable_bedrock_guardrail=true' \
  -var='enable_graphrag=true'
```

For a cheaper smoke test without Neptune Analytics and Bedrock Knowledge Base creation:

```bash
terraform apply \
  -var='aws_region=us-east-1' \
  -var='enable_static_demo_site=true' \
  -var='enable_bedrock_guardrail=true' \
  -var='enable_graphrag=false'
```

## Validate

```bash
terraform output
```

Open the static demo URL:

```bash
terraform output -raw static_demo_site_url
```

The static site includes:

- `index.html`: overview and navigation.
- `basic-rag.html`: RAG común with an editable question. It calls the Basic RAG Knowledge Base only.
- `ai-ready-rag.html`: AI-Ready GraphRAG + Agent with an editable question. It calls the GraphRAG Knowledge Base and validates structured transaction data.

Check the seeded synthetic transaction:

```bash
terraform state show 'aws_dynamodb_table_item.transactions["TX-991"]'
```

Inspect Terraform-managed RAG resources:

```bash
terraform output -raw bedrock_basic_knowledge_base_id
terraform output -raw bedrock_basic_data_source_id
terraform state list | grep bedrock
terraform state list | grep neptune
```

Terraform creates the Basic RAG and AI-Ready GraphRAG Knowledge Bases and data sources. Bedrock ingestion/sync jobs are short-lived service operations, not persistent infrastructure resources exposed by the AWS provider. To ingest documents, open the Bedrock Knowledge Bases console, select each data source created by Terraform, and choose **Sync**.

Use the site after both sync jobs complete. The Basic RAG page retrieves only from raw PDF chunks. The AI-Ready page retrieves from GraphRAG and enriches answers with DynamoDB transaction/product/customer context.

Inspect the Lambda names for console invocation:

```bash
terraform output -raw rag_api_url
terraform output -raw lambda_create_claim_case
terraform output -raw lambda_request_card_block
```

## Destroy Everything

Run destroy from the same Terraform directory.

```bash
terraform destroy \
  -var='aws_region=us-east-1' \
  -var='enable_static_demo_site=true' \
  -var='enable_bedrock_guardrail=true' \
  -var='enable_graphrag=true'
```

After destroy, Terraform state should be empty:

```bash
terraform state list
```
