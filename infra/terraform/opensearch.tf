resource "aws_opensearchserverless_security_policy" "encryption" {
  name = "${local.name_prefix}-enc"
  type = "encryption"

  policy = jsonencode({
    Rules = [{
      ResourceType = "collection"
      Resource     = ["collection/${local.name_prefix}-vector"]
    }]
    AWSOwnedKey = true
  })
}

resource "aws_opensearchserverless_security_policy" "network" {
  name = "${local.name_prefix}-net"
  type = "network"

  policy = jsonencode([
    {
      Rules = [
        {
          ResourceType = "collection"
          Resource     = ["collection/${local.name_prefix}-vector"]
        },
        {
          ResourceType = "dashboard"
          Resource     = ["collection/${local.name_prefix}-vector"]
        }
      ]
      AllowFromPublic = true
    }
  ])
}

resource "aws_opensearchserverless_access_policy" "access" {
  name = "${local.name_prefix}-access"
  type = "data"

  policy = jsonencode([
    {
      Rules = [
        {
          ResourceType = "collection"
          Resource     = ["collection/${local.name_prefix}-vector"]
          Permission   = ["aoss:*"]
        },
        {
          ResourceType = "index"
          Resource     = ["index/${local.name_prefix}-vector/*"]
          Permission   = ["aoss:*"]
        }
      ]
      Principal = [
        aws_iam_role.bedrock_kb_role.arn,
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      ]
    }
  ])
}

resource "aws_opensearchserverless_collection" "vector" {
  name = "${local.name_prefix}-vector"
  type = "VECTORSEARCH"

  depends_on = [
    aws_opensearchserverless_security_policy.encryption,
    aws_opensearchserverless_security_policy.network,
    aws_opensearchserverless_access_policy.access
  ]
}
