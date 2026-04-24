resource "aws_datazone_domain" "demo" {
  count = var.enable_datazone ? 1 : 0

  name                  = "${local.name_prefix}-domain"
  description           = "DataZone domain for AI-Ready RAG lineage demo"
  domain_execution_role = aws_iam_role.datazone_domain_execution[0].arn
  domain_version        = "V2"
}
