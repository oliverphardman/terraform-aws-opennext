locals {
  server_origin_id             = "${var.slug}-server-origin"
  assets_origin_id             = "${var.slug}-assets-origin"
  image_optimization_origin_id = "${var.slug}-image-optimization-origin"
}

resource "aws_cloudfront_function" "this" {
  count = var.enable_www_alias == true ? 1 : 0

  name    = "${var.slug}PreserveHost"
  runtime = "cloudfront-js-2.0"
  comment = "Next.js function for preserving original host and redirecting www"
  publish = true
  code    = file("${path.module}/www_redirect.js")

  lifecycle {
    create_before_destroy = true
  }
}

data "aws_s3_bucket" "this" {
  bucket = var.assets_bucket_name
}

# S3 Bucket Policy for OAC
data "aws_iam_policy_document" "this" {
  statement {
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${data.aws_s3_bucket.this.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [aws_cloudfront_distribution.this.arn]
    }
  }

  statement {
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"]
    resources = [data.aws_s3_bucket.this.arn, "${data.aws_s3_bucket.this.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = [var.server_function_role_arn]
    }
  }

  statement {
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [data.aws_s3_bucket.this.arn, "${data.aws_s3_bucket.this.arn}/*"]

    condition {
      test     = "Bool"
      values   = ["false"]
      variable = "aws:SecureTransport"
    }

    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

resource "aws_s3_bucket_policy" "this" {
  bucket = var.assets_bucket_name
  policy = data.aws_iam_policy_document.this.json

  depends_on = [aws_cloudfront_distribution.this]
}

data "aws_cloudfront_cache_policy" "static" {
  name = "Managed-CachingOptimized"
}

data "aws_cloudfront_origin_request_policy" "this" {
  count = var.origin_request_policy == null ? 1 : 0

  name = "Managed-AllViewerExceptHostHeader"
}

resource "aws_cloudfront_origin_request_policy" "this" {
  count = var.origin_request_policy == null ? 0 : 1

  name = "${var.slug}OriginRequestPolicy"

  cookies_config {
    cookie_behavior = var.origin_request_policy.cookies_config.cookie_behavior
    cookies {
      items = var.origin_request_policy.cookies_config.items
    }
  }

  headers_config {
    header_behavior = var.origin_request_policy.headers_config.header_behavior

    headers {
      items = concat(
        ["accept", "rsc", "next-router-prefetch", "next-router-state-tree", "next-url", "x-prerender-revalidate"],
        coalesce(var.origin_request_policy.headers_config.items, [])
      )
    }
  }

  query_strings_config {
    query_string_behavior = var.origin_request_policy.query_strings_config.query_string_behavior
    query_strings {
      items = var.origin_request_policy.query_strings_config.items
    }
  }
}

resource "aws_cloudfront_cache_policy" "this" {
  name = "${var.slug}CachePolicy"

  default_ttl = var.cache_policy.default_ttl
  min_ttl     = var.cache_policy.min_ttl
  max_ttl     = var.cache_policy.max_ttl

  parameters_in_cache_key_and_forwarded_to_origin {
    enable_accept_encoding_brotli = var.cache_policy.enable_accept_encoding_brotli
    enable_accept_encoding_gzip   = var.cache_policy.enable_accept_encoding_gzip

    cookies_config {
      cookie_behavior = var.cache_policy.cookies_config.cookie_behavior

      dynamic "cookies" {
        for_each = var.cache_policy.cookies_config.items != null && length(var.cache_policy.cookies_config.items) > 0 ? [true] : []

        content {
          items = var.cache_policy.cookies_config.items
        }
      }
    }

    headers_config {
      header_behavior = var.cache_policy.headers_config.header_behavior

      headers {
        items = concat(
          ["accept", "rsc", "next-router-prefetch", "next-router-state-tree", "next-url", "x-prerender-revalidate"],
          coalesce(var.cache_policy.headers_config.items, [])
        )
      }
    }

    query_strings_config {
      query_string_behavior = var.cache_policy.query_strings_config.query_string_behavior

      dynamic "query_strings" {
        for_each = var.cache_policy.query_strings_config.items != null && length(var.cache_policy.query_strings_config.items) > 0 ? [true] : []

        content {
          items = var.cache_policy.query_strings_config.items
        }
      }
    }
  }
}

resource "aws_cloudfront_response_headers_policy" "this" {
  name    = "${var.slug}ResponseHeadersPolicy"
  comment = "${var.slug} Response Headers Policy"

  cors_config {
    origin_override                  = var.cors.origin_override
    access_control_allow_credentials = var.cors.allow_credentials

    access_control_allow_headers {
      items = var.cors.allow_headers
    }

    access_control_allow_methods {
      items = var.cors.allow_methods
    }

    access_control_allow_origins {
      items = var.cors.allow_origins
    }
  }

  security_headers_config {
    strict_transport_security {
      access_control_max_age_sec = var.hsts.access_control_max_age_sec
      include_subdomains         = var.hsts.include_subdomains
      override                   = var.hsts.override
      preload                    = var.hsts.preload
    }
  }

  dynamic "custom_headers_config" {
    for_each = length(var.custom_headers) > 0 ? [true] : []

    content {
      dynamic "items" {
        for_each = toset(var.custom_headers)

        content {
          header   = items.header
          override = items.override
          value    = items.value
        }
      }
    }
  }

  dynamic "remove_headers_config" {
    for_each = length(var.remove_headers_config.items) > 0 ? [true] : []

    content {
      dynamic "items" {
        for_each = toset(var.remove_headers_config.items)

        content {
          header = items.value
        }
      }
    }
  }
}

resource "aws_cloudfront_distribution" "this" {
  price_class     = var.price_class
  enabled         = true
  is_ipv6_enabled = true
  comment         = var.name
  aliases         = var.aliases
  web_acl_id      = try(var.custom_waf.arn, null)
  http_version    = "http2and3"

  viewer_certificate {
    acm_certificate_arn      = var.acm_certificate_arn
    minimum_protocol_version = "TLSv1.2_2021"
    ssl_support_method       = "sni-only"
  }

  restrictions {
    geo_restriction {
      restriction_type = var.geo_restriction.restriction_type
      locations        = var.geo_restriction.locations
    }
  }

  # S3 Bucket Origin
  origin {
    domain_name = var.origins.assets_bucket
    origin_id   = local.assets_origin_id
    origin_path = "/_assets"

    origin_access_control_id = var.assets_origin_access_control_id
  }

  # Server Function Origin
  origin {
    domain_name              = var.origins.server_function
    origin_id                = local.server_origin_id
    origin_access_control_id = var.server_function_oac_id
  }

  # Image Optimization Function Origin
  origin {
    domain_name              = var.origins.image_optimization_function
    origin_id                = local.image_optimization_origin_id
    origin_access_control_id = var.image_optimization_function_oac_id
  }

  # Behaviour - Hashed Static Files (/_next/static/*)
  ordered_cache_behavior {
    path_pattern     = "/_next/static/*"
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.assets_origin_id

    response_headers_policy_id = aws_cloudfront_response_headers_policy.this.id
    cache_policy_id            = data.aws_cloudfront_cache_policy.static.id

    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  ordered_cache_behavior {
    path_pattern     = "/_next/image"
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.image_optimization_origin_id

    response_headers_policy_id = aws_cloudfront_response_headers_policy.this.id
    cache_policy_id            = aws_cloudfront_cache_policy.this.id
    origin_request_policy_id = try(
      data.aws_cloudfront_origin_request_policy.this[0].id,
      aws_cloudfront_origin_request_policy.this[0].id
    )

    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  ordered_cache_behavior {
    path_pattern     = "/_next/data/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = local.server_origin_id

    response_headers_policy_id = aws_cloudfront_response_headers_policy.this.id
    cache_policy_id            = aws_cloudfront_cache_policy.this.id
    origin_request_policy_id = try(
      data.aws_cloudfront_origin_request_policy.this[0].id,
      aws_cloudfront_origin_request_policy.this[0].id
    )

    compress               = true
    viewer_protocol_policy = "redirect-to-https"

    dynamic "function_association" {
      for_each = var.enable_www_alias == true ? [true] : []

      content {
        event_type   = "viewer-request"
        function_arn = aws_cloudfront_function.this.arn
      }
    }
  }

  ordered_cache_behavior {
    path_pattern     = "/api/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS", "PUT", "PATCH", "POST", "DELETE"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = local.server_origin_id

    response_headers_policy_id = aws_cloudfront_response_headers_policy.this.id
    cache_policy_id            = aws_cloudfront_cache_policy.this.id
    origin_request_policy_id = try(
      data.aws_cloudfront_origin_request_policy.this[0].id,
      aws_cloudfront_origin_request_policy.this[0].id
    )

    compress               = true
    viewer_protocol_policy = "redirect-to-https"

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.this.arn
    }
  }

  ordered_cache_behavior {
    path_pattern     = "/static/*"
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.assets_origin_id

    response_headers_policy_id = aws_cloudfront_response_headers_policy.this.id
    cache_policy_id            = data.aws_cloudfront_cache_policy.static.id

    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  dynamic "ordered_cache_behavior" {
    for_each = toset(var.assets_paths)

    content {
      path_pattern     = ordered_cache_behavior.value
      allowed_methods  = ["GET", "HEAD", "OPTIONS"]
      cached_methods   = ["GET", "HEAD", "OPTIONS"]
      target_origin_id = local.assets_origin_id

      response_headers_policy_id = aws_cloudfront_response_headers_policy.this.id
      cache_policy_id            = data.aws_cloudfront_cache_policy.static.id

      compress               = true
      viewer_protocol_policy = "redirect-to-https"
    }
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS", "PUT", "PATCH", "POST", "DELETE"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = local.server_origin_id

    response_headers_policy_id = aws_cloudfront_response_headers_policy.this.id
    cache_policy_id            = aws_cloudfront_cache_policy.this.id
    origin_request_policy_id = try(
      data.aws_cloudfront_origin_request_policy.this[0].id,
      aws_cloudfront_origin_request_policy.this[0].id
    )

    compress               = true
    viewer_protocol_policy = "redirect-to-https"

    dynamic "function_association" {
      for_each = var.enable_www_alias == true ? [true] : []

      content {
        event_type   = "viewer-request"
        function_arn = aws_cloudfront_function.this.arn
      }

    }
  }

  tags = {
    Name = var.name
  }
}

resource "aws_s3_bucket" "log" {
  bucket           = "${var.slug}-logs-${var.aws_account_id}-${var.aws_region}-an"
  bucket_namespace = "account-regional"
  force_destroy    = true
}

resource "aws_s3_bucket_lifecycle_configuration" "log" {
  bucket = aws_s3_bucket.log.id

  rule {
    id     = "glacier-transition"
    status = "Enabled"

    filter {}

    transition {
      days          = 7
      storage_class = "GLACIER_IR"
    }

    expiration {
      days = 90
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}

resource "aws_s3_bucket_public_access_block" "log" {
  bucket = aws_s3_bucket.log.id

  block_public_acls       = true
  block_public_policy     = true
  restrict_public_buckets = true
  ignore_public_acls      = true
}
