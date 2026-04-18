locals {
  server_origin_id             = "${var.slug}ServerOrigin"
  assets_origin_id             = "${var.slug}AssetsOrigin"
  image_optimization_origin_id = "${var.slug}ImageOptimizationOrigin"
}

resource "aws_cloudfront_function" "this" {
  name    = "${var.slug}HostHeader"
  runtime = "cloudfront-js-2.0"
  comment = "Sets x-forwarded-host header required by OpenNext"
  publish = true
  code    = file("${path.module}/host_header.js")

  lifecycle {
    create_before_destroy = true
  }
}

locals {
  assets_bucket_arn = "arn:aws:s3:::${var.assets_bucket_name}"
}

# S3 Bucket Policy for OAC
resource "aws_s3_bucket_policy" "this" {
  bucket = var.assets_bucket_name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Action    = "s3:GetObject"
        Resource  = "${local.assets_bucket_arn}/*"
        Principal = { Service = "cloudfront.amazonaws.com" }
        Condition = {
          StringEquals = {
            "aws:SourceArn" = aws_cloudfront_distribution.this.arn
          }
        }
      },
      {
        Effect    = "Allow"
        Action    = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"]
        Resource  = [local.assets_bucket_arn, "${local.assets_bucket_arn}/*"]
        Principal = { AWS = var.server_function_role_arn }
      },
      {
        Effect    = "Deny"
        Action    = "s3:*"
        Resource  = [local.assets_bucket_arn, "${local.assets_bucket_arn}/*"]
        Principal = "*"
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
    ]
  })

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
  comment = "${var.name} Response Headers Policy"

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
    domain_name = var.origins.server_function
    origin_id   = local.server_origin_id

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      ip_address_type        = "dualstack"
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # Image Optimization Function Origin
  origin {
    domain_name = var.origins.image_optimization_function
    origin_id   = local.image_optimization_origin_id

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      ip_address_type        = "dualstack"
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
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

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.this.arn
    }
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

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.this.arn
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

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.this.arn
    }
  }

  tags = merge(
    var.tags,
    {
      Name = var.name
    }
  )
}

resource "aws_s3_bucket" "log" {
  bucket           = "${lower(var.slug)}-logs-${var.aws_account_id}-${var.aws_region}-an"
  bucket_namespace = "account-regional"
  force_destroy    = true

  tags = var.tags
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
