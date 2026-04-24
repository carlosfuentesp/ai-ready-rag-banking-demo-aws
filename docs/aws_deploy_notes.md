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

Terraform creates GraphRAG resources when `enable_graphrag=true`:

1. Neptune Analytics graph.
2. Bedrock Knowledge Base with `NEPTUNE_ANALYTICS` storage.
3. S3 data source with semantic chunking configuration.

Bedrock ingestion/sync jobs are short-lived service operations, not persistent infrastructure resources exposed by the AWS provider. If you need to run ingestion, use the Bedrock Knowledge Bases console after Terraform creates the data source.

## DataZone lineage

The repo includes OpenLineage-compatible curated JSONL assets. DataZone domain provisioning is managed by Terraform when `enable_datazone=true`.

## Cost warning

Neptune Analytics, OpenSearch Serverless, Bedrock ingestion and model calls can incur costs. Destroy resources after the demo:

```bash
cd infra/terraform
terraform destroy
```

All persistent demo resources are managed by Terraform state. Destroy from the same workspace used to apply.
