# AWS Full Test Runbook

This runbook deploys the synthetic banking RAG demo to AWS with Terraform-managed lifecycle. Use a sandbox AWS account and destroy the stack when finished.

## What Terraform Creates

- S3 buckets for raw, curated, and optional static demo UI assets.
- DynamoDB tables and synthetic seed items.
- Lambda functions for claim creation and preventive card block request.
- OpenSearch Serverless vector collection.
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
- `basic-rag.html`: RAG común with the shared banking question.
- `ai-ready-rag.html`: AI-Ready GraphRAG + Agent with the same question.

Check the seeded synthetic transaction:

```bash
terraform state show 'aws_dynamodb_table_item.transactions["TX-991"]'
```

Inspect Terraform-managed GraphRAG resources:

```bash
terraform state list | grep bedrock
terraform state list | grep neptune
```

If `enable_graphrag=true`, the Bedrock Knowledge Base and S3 data source are created by Terraform. Bedrock ingestion/sync jobs are short-lived service operations, not persistent infrastructure resources exposed by the AWS provider. To run an ingestion job, open the Bedrock Knowledge Bases console, select the data source created by Terraform, and choose **Sync**.

Inspect the Lambda names for console invocation:

```bash
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
