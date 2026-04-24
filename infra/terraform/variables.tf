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
  default     = true
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
  default     = true
}

variable "enable_datazone" {
  description = "When true, Terraform creates a DataZone domain and scripts can emit lineage events."
  type        = bool
  default     = false
}

variable "embedding_model_arn" {
  description = "Embedding model ARN for Bedrock Knowledge Bases."
  type        = string
  default     = "arn:aws:bedrock:us-east-1::foundation-model/amazon.titan-embed-text-v2:0"
}

variable "generation_model_id" {
  description = "Bedrock model id used by the query Lambda to generate answers from retrieved context."
  type        = string
  default     = "us.anthropic.claude-haiku-4-5-20251001-v1:0"
}

variable "graph_context_model_id" {
  description = "Bedrock foundation model id used by GraphRAG context enrichment to extract chunk entities."
  type        = string
  default     = "amazon.nova-lite-v1:0"
}

variable "embedding_dimension" {
  description = "Embedding vector dimension used by the Bedrock Knowledge Base and Neptune Analytics vector search."
  type        = number
  default     = 1024
}

variable "neptune_graph_provisioned_memory" {
  description = "Provisioned memory-optimized Neptune Capacity Units (m-NCUs) for the GraphRAG Neptune Analytics graph."
  type        = number
  default     = 16
}

variable "auto_start_ingestion_jobs" {
  description = "When true, Terraform invokes an AWS Lambda resource to start Bedrock Knowledge Base ingestion jobs after data sources are created."
  type        = bool
  default     = true
}

variable "ingestion_wait_seconds" {
  description = "Maximum seconds for the Terraform-managed ingestion Lambda to wait for each Bedrock ingestion job."
  type        = number
  default     = 840
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

variable "data_root_path" {
  description = "Path to data directory relative to Terraform root."
  type        = string
  default     = "../../data"
}
