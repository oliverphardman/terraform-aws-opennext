locals {
  content_type_lookup = {
    css   = "text/css"
    otf   = "font/otf"
    woff  = "font/woff"
    woff2 = "font/woff2"
    ttf   = "font/ttf"
    js    = "application/javascript"
    svg   = "image/svg+xml"
    ico   = "image/x-icon"
    html  = "text/html"
    htm   = "text/html"
    json  = "application/json"
    png   = "image/png"
    jpg   = "image/jpeg"
    jpeg  = "image/jpeg"
    webp  = "image/webp"
  }
}

resource "aws_s3_bucket" "assets" {
  bucket           = var.use_account_regional_buckets ? "${lower(var.slug)}-assets-${data.aws_caller_identity.current.account_id}-${var.aws_region}-an" : "${lower(var.slug)}-assets"
  bucket_namespace = var.use_account_regional_buckets ? "account-regional" : "global"
  force_destroy    = true
}

resource "aws_s3_bucket_public_access_block" "assets" {
  bucket = aws_s3_bucket.assets.bucket

  block_public_acls       = true
  block_public_policy     = true
  restrict_public_buckets = true
  ignore_public_acls      = true
}

resource "aws_s3_bucket_versioning" "assets" {
  bucket = aws_s3_bucket.assets.bucket

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "assets" {
  bucket = aws_s3_bucket.assets.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_replication_configuration" "assets" {
  count = var.replication_configuration == null ? 0 : 1

  bucket = aws_s3_bucket.assets.bucket
  role   = var.replication_configuration.role

  dynamic "rule" {
    for_each = toset(var.replication_configuration.rules)

    content {
      id     = rule.value.id
      status = rule.value.status

      dynamic "filter" {
        for_each = toset(rule.value.filters)

        content {
          prefix = filter.value.prefix
        }
      }

      destination {
        bucket        = rule.value.destination.bucket
        storage_class = rule.value.destination.storage_class
      }
    }
  }

  depends_on = [aws_s3_bucket_versioning.assets]
}

resource "aws_s3_bucket_lifecycle_configuration" "assets" {
  bucket = aws_s3_bucket.assets.bucket

  rule {
    id     = "abort-failed-uploads"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }

  rule {
    id     = "clear-versioned-assets"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_transition {
      noncurrent_days = 60
      storage_class   = "GLACIER_IR"
    }
  }

  depends_on = [aws_s3_bucket_versioning.assets]
}

resource "aws_cloudfront_origin_access_control" "assets" {
  name                              = "${var.slug}AssetsOAC"
  description                       = "CloudFront OAC for Assets S3 Bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_s3_object" "assets" {
  for_each = var.upload_files ? fileset("${local.opennext_root_build_path}/assets", "**") : toset([])

  bucket       = aws_s3_bucket.assets.bucket
  key          = "_assets/${each.value}"
  source       = "${local.opennext_root_build_path}/assets/${each.value}"
  source_hash  = filemd5("${local.opennext_root_build_path}/assets/${each.value}")
  content_type = lookup(local.content_type_lookup, split(".", each.value)[length(split(".", each.value)) - 1], "text/plain")

  depends_on = [aws_s3_bucket.assets]
  tags       = var.tags
}

resource "aws_s3_object" "cache" {
  for_each = var.upload_files ? fileset("${local.opennext_root_build_path}/cache", "**") : toset([])

  bucket       = aws_s3_bucket.assets.bucket
  key          = "_cache/${each.value}"
  source       = "${local.opennext_root_build_path}/cache/${each.value}"
  source_hash  = filemd5("${local.opennext_root_build_path}/cache/${each.value}")
  content_type = lookup(local.content_type_lookup, split(".", each.value)[length(split(".", each.value)) - 1], "text/plain")

  depends_on = [aws_s3_bucket.assets]
  tags       = var.tags
}
