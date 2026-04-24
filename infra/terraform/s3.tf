resource "aws_s3_bucket" "raw" {
  bucket        = "${local.name_prefix}-raw"
  force_destroy = true
}

resource "aws_s3_bucket" "curated" {
  bucket        = "${local.name_prefix}-curated"
  force_destroy = true
}

resource "aws_s3_bucket" "app" {
  bucket        = "${local.name_prefix}-app"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "all" {
  for_each = merge(
    {
      raw     = aws_s3_bucket.raw.id
      curated = aws_s3_bucket.curated.id
    },
    var.enable_static_demo_site ? {} : { app = aws_s3_bucket.app.id }
  )

  bucket                  = each.value
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "all" {
  for_each = {
    raw     = aws_s3_bucket.raw.id
    curated = aws_s3_bucket.curated.id
    app     = aws_s3_bucket.app.id
  }

  bucket = each.value
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_object" "raw_data" {
  for_each = {
    for file in local.raw_files : file => file
    if !endswith(file, ".png")
  }

  bucket = aws_s3_bucket.raw.id
  key    = each.value
  source = "${local.data_root}/${each.value}"
  etag   = filemd5("${local.data_root}/${each.value}")
}

resource "aws_s3_object" "curated_data" {
  for_each = {
    for file in local.curated_files : file => file
  }

  bucket = aws_s3_bucket.curated.id
  key    = each.value
  source = "${local.data_root}/${each.value}"
  etag   = filemd5("${local.data_root}/${each.value}")
}
