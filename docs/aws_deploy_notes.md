# AWS Deployment Notes

## Region

Use an AWS region where the following are available in your account:

- Amazon Bedrock models,
- Bedrock Knowledge Bases,
- Bedrock Agents,
- Bedrock Guardrails,
- Amazon Neptune Analytics,
- Amazon OpenSearch Serverless,
- Amazon DataZone if lineage UI is required.

## Model access

Enable model access in Amazon Bedrock before creating knowledge bases.

Default model ARNs in Terraform variables may need to change by region/account.

## GraphRAG

Terraform invokes the AWS CLI script when `enable_bedrock_cli=true`. The script creates:

1. Neptune Analytics graph.
2. Bedrock Knowledge Base with `NEPTUNE_ANALYTICS` storage.
3. S3 data source with context enrichment and `CHUNK_ENTITY_EXTRACTION`.

The matching Terraform destroy hook runs `scripts/aws_cli/destroy_bedrock_graphrag_kb.sh`.

## DataZone lineage

The repo emits local OpenLineage-compatible JSONL. The final API submission depends on the DataZone lineage API version enabled in your region/account. This is intentionally isolated in `scripts/aws_cli/emit_datazone_lineage.sh`.

## Cost warning

Neptune Analytics, OpenSearch Serverless, Bedrock ingestion and model calls can incur costs. Destroy resources after the demo:

```bash
cd infra/terraform
terraform destroy
```

CLI-created Bedrock/Neptune resources are wired to Terraform destroy hooks. Keep the `outputs/` directory until after `terraform destroy` because those JSON files contain the resource identifiers used by cleanup scripts.
