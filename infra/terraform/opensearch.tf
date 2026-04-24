resource "aws_opensearchserverless_security_policy" "encryption" {
  name = local.opensearch_enc_name
  type = "encryption"

  policy = jsonencode({
    Rules = [{
      ResourceType = "collection"
      Resource     = ["collection/${local.opensearch_name}"]
    }]
    AWSOwnedKey = true
  })
}

resource "aws_opensearchserverless_security_policy" "network" {
  name = local.opensearch_net_name
  type = "network"

  policy = jsonencode([
    {
      Rules = [
        {
          ResourceType = "dashboard"
          Resource     = ["collection/${local.opensearch_name}"]
        },
        {
          ResourceType = "collection"
          Resource     = ["collection/${local.opensearch_name}"]
        }
      ]
      AllowFromPublic = true
    }
  ])
}

resource "aws_opensearchserverless_access_policy" "access" {
  name = local.opensearch_acc_name
  type = "data"

  policy = jsonencode([
    {
      Rules = [
        {
          ResourceType = "collection"
          Resource     = ["collection/${local.opensearch_name}"]
          Permission   = ["aoss:*"]
        },
        {
          ResourceType = "index"
          Resource     = ["index/${local.opensearch_name}/*"]
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
  name = local.opensearch_name
  type = "VECTORSEARCH"

  depends_on = [
    aws_opensearchserverless_security_policy.encryption,
    aws_opensearchserverless_security_policy.network,
    aws_opensearchserverless_access_policy.access
  ]
}
