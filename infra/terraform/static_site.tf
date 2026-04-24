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

resource "aws_s3_object" "static_demo_site" {
  count        = var.enable_static_demo_site ? 1 : 0
  bucket       = aws_s3_bucket.app.id
  key          = "index.html"
  source       = "${path.module}/../../app/static/index.html"
  etag         = filemd5("${path.module}/../../app/static/index.html")
  content_type = "text/html; charset=utf-8"

  depends_on = [aws_s3_bucket_policy.app_site]
}
