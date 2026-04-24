variable "project_name" {
  description = "Prefix for all resources."
  type        = string
  default     = "ai-ready-rag-bank"
}

variable "environment" {
  description = "Environment name."
  type        = string
  default     = "demo"
}

variable "aws_region" {
  description = "AWS region. Use a region where Bedrock, Knowledge Bases, and Neptune Analytics are supported."
  type        = string
  default     = "us-east-1"
}

variable "enable_bedrock_cli" {
  description = "When true, Terraform invokes AWS CLI scripts for Bedrock GraphRAG resources and registers destroy hooks for cleanup."
  type        = bool
  default     = false
}

variable "enable_bedrock_guardrail" {
  description = "When true, Terraform invokes AWS CLI scripts to create a Bedrock Guardrail and registers a destroy hook for cleanup."
  type        = bool
  default     = true
}

variable "seed_dynamodb_tables" {
  description = "When true, Terraform loads the synthetic CSV seed rows into DynamoDB tables."
  type        = bool
  default     = true
}

variable "enable_static_demo_site" {
  description = "When true, Terraform publishes a public S3 static site with the side-by-side demo summary."
  type        = bool
  default     = false
}

variable "enable_datazone" {
  description = "When true, Terraform creates a DataZone domain and scripts can emit lineage events."
  type        = bool
  default     = false
}

variable "embedding_model_arn" {
  description = "Embedding model ARN for Bedrock Knowledge Bases."
  type        = string
  default     = "arn:aws:bedrock:us-east-1::foundation-model/cohere.embed-multilingual-v3"
}

variable "graph_enrichment_model_arn" {
  description = "Model ARN used for GraphRAG context enrichment and entity extraction."
  type        = string
  default     = "arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-3-haiku-20240307-v1:0"
}

variable "neptune_provisioned_memory" {
  description = "Minimum is 16 m-NCUs."
  type        = number
  default     = 16
}

variable "local_data_root" {
  description = "Path to local data directory relative to Terraform root."
  type        = string
  default     = "../../data"
}
