resource "aws_s3_bucket_website_configuration" "app" {
  count  = var.enable_static_demo_site ? 1 : 0
  bucket = aws_s3_bucket.app.id

  index_document {
    suffix = "index.html"
  }
}

resource "aws_s3_bucket_public_access_block" "app_site" {
  count  = var.enable_static_demo_site ? 1 : 0
  bucket = aws_s3_bucket.app.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "app_site" {
  count  = var.enable_static_demo_site ? 1 : 0
  bucket = aws_s3_bucket.app.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowPublicReadForDemoSite"
      Effect    = "Allow"
      Principal = "*"
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.app.arn}/*"
    }]
  })

  depends_on = [aws_s3_bucket_public_access_block.app_site]
}

locals {
  static_site_files = fileset("${path.module}/../../app/static", "**/*")
  static_site_content_types = {
    css  = "text/css; charset=utf-8"
    html = "text/html; charset=utf-8"
    js   = "application/javascript; charset=utf-8"
    json = "application/json; charset=utf-8"
    png  = "image/png"
    svg  = "image/svg+xml"
  }
}

resource "aws_s3_object" "static_demo_site" {
  for_each = var.enable_static_demo_site ? local.static_site_files : []

  bucket       = aws_s3_bucket.app.id
  key          = each.value
  source       = "${path.module}/../../app/static/${each.value}"
  etag         = filemd5("${path.module}/../../app/static/${each.value}")
  content_type = lookup(local.static_site_content_types, lower(regex("[^.]+$", each.value)), "application/octet-stream")

  depends_on = [aws_s3_bucket_policy.app_site]
}

resource "aws_s3_object" "runtime_config" {
  count  = var.enable_static_demo_site ? 1 : 0
  bucket = aws_s3_bucket.app.id
  key    = "config.js"
  content = join("\n", [
    "window.RAG_API_URL = ${jsonencode("${aws_apigatewayv2_api.rag.api_endpoint}/query")};",
    "window.CREATE_CLAIM_API_URL = ${jsonencode("${aws_apigatewayv2_api.rag.api_endpoint}/actions/create-claim-case")};",
    "window.REQUEST_CARD_BLOCK_API_URL = ${jsonencode("${aws_apigatewayv2_api.rag.api_endpoint}/actions/request-card-block")};",
    "",
  ])
  content_type = "application/javascript; charset=utf-8"
  etag = md5(join("\n", [
    "window.RAG_API_URL = ${jsonencode("${aws_apigatewayv2_api.rag.api_endpoint}/query")};",
    "window.CREATE_CLAIM_API_URL = ${jsonencode("${aws_apigatewayv2_api.rag.api_endpoint}/actions/create-claim-case")};",
    "window.REQUEST_CARD_BLOCK_API_URL = ${jsonencode("${aws_apigatewayv2_api.rag.api_endpoint}/actions/request-card-block")};",
    "",
  ]))

  depends_on = [aws_s3_bucket_policy.app_site]
}
