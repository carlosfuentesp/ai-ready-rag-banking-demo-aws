# AWS Full Test Runbook

This runbook deploys the synthetic banking RAG demo to AWS with Terraform-managed lifecycle. Use a sandbox AWS account and destroy the stack when finished.

## What Terraform Creates

- S3 buckets for raw, curated, and optional static demo UI assets.
- DynamoDB tables and synthetic seed items.
- Lambda functions for claim creation and preventive card block request.
- OpenSearch Serverless vector collection.
- Bedrock Guardrail through a Terraform `local-exec` lifecycle hook.
- Optional Bedrock GraphRAG Knowledge Base and Neptune Analytics graph through Terraform `local-exec` lifecycle hooks.
- Optional DataZone domain.

Bedrock GraphRAG APIs evolve quickly, so this repo keeps those calls in parameterized AWS CLI scripts. They are still invoked by Terraform, and matching destroy hooks are registered so `terraform destroy` cleans them up.

## Prerequisites

- AWS CLI v2 authenticated to the target account.
- Terraform >= 1.6.
- `jq`.
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
  -var='enable_bedrock_cli=true'
```

For a cheaper smoke test without Neptune Analytics and Bedrock Knowledge Base creation:

```bash
terraform apply \
  -var='aws_region=us-east-1' \
  -var='enable_static_demo_site=true' \
  -var='enable_bedrock_guardrail=true' \
  -var='enable_bedrock_cli=false'
```

## Validate

```bash
terraform output
```

Open the static demo URL:

```bash
terraform output -raw static_demo_site_url
```

Check the seeded synthetic transaction:

```bash
aws dynamodb get-item \
  --region us-east-1 \
  --table-name "$(terraform output -json dynamodb_tables | jq -r '.transactions')" \
  --key '{"transaction_id":{"S":"TX-991"}}'
```

Invoke claim creation:

```bash
aws lambda invoke \
  --region us-east-1 \
  --function-name "$(terraform output -raw lambda_create_claim_case)" \
  --cli-binary-format raw-in-base64-out \
  --payload '{"customer_id":"C-1023","transaction_id":"TX-991","requested_by":"demo-asesor"}' \
  /tmp/create_claim_case.json
cat /tmp/create_claim_case.json
```

Invoke preventive block request:

```bash
aws lambda invoke \
  --region us-east-1 \
  --function-name "$(terraform output -raw lambda_request_card_block)" \
  --cli-binary-format raw-in-base64-out \
  --payload '{"customer_id":"C-1023","product_id":"P-TC-001","requested_by":"demo-asesor","confirmation_token":"CONFIRM-DEMO"}' \
  /tmp/request_card_block.json
cat /tmp/request_card_block.json
```

If `enable_bedrock_cli=true`, inspect the created GraphRAG outputs:

```bash
cat ../../outputs/bedrock_graphrag_kb.json
cat ../../outputs/bedrock_graphrag_data_source.json
cat ../../outputs/bedrock_graphrag_ingestion_job.json
```

Inspect the guardrail:

```bash
cat ../../outputs/bedrock_guardrail.json
```

## Destroy Everything

Run destroy from the same Terraform directory. The destroy hooks delete CLI-created Bedrock Guardrail, Bedrock Knowledge Base, data source, and Neptune Analytics graph.

```bash
terraform destroy \
  -var='aws_region=us-east-1' \
  -var='enable_static_demo_site=true' \
  -var='enable_bedrock_guardrail=true' \
  -var='enable_bedrock_cli=true'
```

After destroy, verify there are no remaining resources with the project prefix:

```bash
aws s3 ls | grep ai-ready-rag-bank || true
aws dynamodb list-tables --region us-east-1 | grep ai-ready-rag-bank || true
aws lambda list-functions --region us-east-1 | grep ai-ready-rag-bank || true
```
