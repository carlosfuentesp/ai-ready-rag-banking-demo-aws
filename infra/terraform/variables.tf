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

variable "enable_graphrag" {
  description = "When true, Terraform creates Neptune Analytics and Bedrock Knowledge Base GraphRAG resources."
  type        = bool
  default     = false
}

variable "enable_basic_rag" {
  description = "When true, Terraform creates a Basic RAG Knowledge Base with fixed-size chunking over raw PDFs only."
  type        = bool
  default     = true
}

variable "enable_bedrock_guardrail" {
  description = "When true, Terraform creates a Bedrock Guardrail."
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

variable "generation_model_id" {
  description = "Bedrock model id used by the query Lambda to generate answers from retrieved context."
  type        = string
  default     = "anthropic.claude-3-haiku-20240307-v1:0"
}

variable "embedding_dimension" {
  description = "Embedding vector dimension used by the Bedrock Knowledge Base and Neptune Analytics vector search."
  type        = number
  default     = 1024
}

variable "semantic_chunking_max_tokens" {
  description = "Max tokens for Bedrock Knowledge Base semantic chunking. Cohere embed multilingual v3 supports up to 512."
  type        = number
  default     = 512

  validation {
    condition     = var.semantic_chunking_max_tokens >= 1 && var.semantic_chunking_max_tokens <= 512
    error_message = "semantic_chunking_max_tokens must be between 1 and 512 for the default Cohere embed multilingual v3 model."
  }
}

variable "basic_chunking_max_tokens" {
  description = "Fixed-size chunk max tokens for the Basic RAG data source."
  type        = number
  default     = 512
}

variable "basic_chunking_overlap_percentage" {
  description = "Fixed-size chunk overlap percentage for the Basic RAG data source."
  type        = number
  default     = 20
}

variable "graph_context_enrichment_model_arn" {
  description = "Foundation model ARN used by Bedrock GraphRAG context enrichment for chunk entity extraction."
  type        = string
  default     = "arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-3-haiku-20240307-v1:0"
}

variable "neptune_provisioned_memory" {
  description = "Minimum is 16 m-NCUs."
  type        = number
  default     = 16
}

variable "data_root_path" {
  description = "Path to data directory relative to Terraform root."
  type        = string
  default     = "../../data"
}
