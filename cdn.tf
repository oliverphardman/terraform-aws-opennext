locals {
  cdn_server_origin_id             = "${var.slug}ServerOrigin"
  cdn_assets_origin_id             = "${var.slug}AssetsOrigin"
  cdn_image_optimization_origin_id = "${var.slug}ImageOptimizationOrigin"
  cdn_aliases                      = var.enable_www_alias ? [var.deployment_domain, "www.${var.deployment_domain}"] : [var.deployment_domain]
  cdn_assets_bucket_arn            = "arn:aws:s3:::${aws_s3_bucket.assets.bucket}"
}

resource "aws_cloudfront_function" "host_header" {
  name    = "${var.slug}HostHeader"
  runtime = "cloudfront-js-2.0"
  comment = "Sets x-forwarded-host header required by OpenNext"
  publish = true
  code    = file("${path.module}/hostHeader.js")

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_s3_bucket_policy" "assets" {
  bucket = aws_s3_bucket.assets.bucket
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Action    = "s3:GetObject"
        Resource  = "${local.cdn_assets_bucket_arn}/*"
        Principal = { Service = "cloudfront.amazonaws.com" }
        Condition = {
          StringEquals = {
            "aws:SourceArn" = aws_cloudfront_distribution.cdn.arn
          }
        }
      },
      {
        Effect    = "Allow"
        Action    = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"]
        Resource  = [local.cdn_assets_bucket_arn, "${local.cdn_assets_bucket_arn}/*"]
        Principal = { AWS = module.server_function.lambda_role.arn }
      },
      {
        Effect    = "Deny"
        Action    = "s3:*"
        Resource  = [local.cdn_assets_bucket_arn, "${local.cdn_assets_bucket_arn}/*"]
        Principal = "*"
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
    ]
  })

  depends_on = [aws_cloudfront_distribution.cdn]
}

data "aws_cloudfront_cache_policy" "static" {
  name = "Managed-CachingOptimized"
}

data "aws_cloudfront_origin_request_policy" "cdn" {
  count = var.cdn_origin_request_policy == null ? 1 : 0

  name = "Managed-AllViewerExceptHostHeader"
}

resource "aws_cloudfront_origin_request_policy" "cdn" {
  count = var.cdn_origin_request_policy == null ? 0 : 1

  name = "${var.slug}OriginRequestPolicy"

  cookies_config {
    cookie_behavior = var.cdn_origin_request_policy.cookies_config.cookie_behavior
    cookies {
      items = var.cdn_origin_request_policy.cookies_config.items
    }
  }

  headers_config {
    header_behavior = var.cdn_origin_request_policy.headers_config.header_behavior

    headers {
      items = concat(
        ["accept", "rsc", "next-router-prefetch", "next-router-state-tree", "next-url", "x-prerender-revalidate"],
        coalesce(var.cdn_origin_request_policy.headers_config.items, [])
      )
    }
  }

  query_strings_config {
    query_string_behavior = var.cdn_origin_request_policy.query_strings_config.query_string_behavior
    query_strings {
      items = var.cdn_origin_request_policy.query_strings_config.items
    }
  }
}

resource "aws_cloudfront_cache_policy" "cdn" {
  name = "${var.slug}CachePolicy"

  default_ttl = var.cdn_cache_policy.default_ttl
  min_ttl     = var.cdn_cache_policy.min_ttl
  max_ttl     = var.cdn_cache_policy.max_ttl

  parameters_in_cache_key_and_forwarded_to_origin {
    enable_accept_encoding_brotli = var.cdn_cache_policy.enable_accept_encoding_brotli
    enable_accept_encoding_gzip   = var.cdn_cache_policy.enable_accept_encoding_gzip

    cookies_config {
      cookie_behavior = var.cdn_cache_policy.cookies_config.cookie_behavior

      dynamic "cookies" {
        for_each = var.cdn_cache_policy.cookies_config.items != null && length(var.cdn_cache_policy.cookies_config.items) > 0 ? [true] : []

        content {
          items = var.cdn_cache_policy.cookies_config.items
        }
      }
    }

    headers_config {
      header_behavior = var.cdn_cache_policy.headers_config.header_behavior

      headers {
        items = concat(
          ["accept", "rsc", "next-router-prefetch", "next-router-state-tree", "next-url", "x-prerender-revalidate"],
          coalesce(var.cdn_cache_policy.headers_config.items, [])
        )
      }
    }

    query_strings_config {
      query_string_behavior = var.cdn_cache_policy.query_strings_config.query_string_behavior

      dynamic "query_strings" {
        for_each = var.cdn_cache_policy.query_strings_config.items != null && length(var.cdn_cache_policy.query_strings_config.items) > 0 ? [true] : []

        content {
          items = var.cdn_cache_policy.query_strings_config.items
        }
      }
    }
  }
}

resource "aws_cloudfront_response_headers_policy" "cdn" {
  name    = "${var.slug}ResponseHeadersPolicy"
  comment = "${var.name} Response Headers Policy"

  cors_config {
    origin_override                  = var.cdn_cors.origin_override
    access_control_allow_credentials = var.cdn_cors.allow_credentials

    access_control_allow_headers {
      items = var.cdn_cors.allow_headers
    }

    access_control_allow_methods {
      items = var.cdn_cors.allow_methods
    }

    access_control_allow_origins {
      items = var.cdn_cors.allow_origins
    }
  }

  security_headers_config {
    strict_transport_security {
      access_control_max_age_sec = var.cdn_hsts.access_control_max_age_sec
      include_subdomains         = var.cdn_hsts.include_subdomains
      override                   = var.cdn_hsts.override
      preload                    = var.cdn_hsts.preload
    }
  }

  dynamic "custom_headers_config" {
    for_each = length(var.cdn_custom_headers) > 0 ? [true] : []

    content {
      dynamic "items" {
        for_each = toset(var.cdn_custom_headers)

        content {
          header   = items.value.header
          override = items.value.override
          value    = items.value.value
        }
      }
    }
  }

  dynamic "remove_headers_config" {
    for_each = length(var.cdn_remove_headers.items) > 0 ? [true] : []

    content {
      dynamic "items" {
        for_each = toset(var.cdn_remove_headers.items)

        content {
          header = items.value
        }
      }
    }
  }
}

resource "aws_cloudfront_distribution" "cdn" {
  price_class     = var.cdn_price_class
  enabled         = true
  is_ipv6_enabled = true
  comment         = var.name
  aliases         = local.cdn_aliases
  web_acl_id      = var.waf_arn
  http_version    = "http2and3"

  viewer_certificate {
    acm_certificate_arn      = var.acm_arn
    minimum_protocol_version = "TLSv1.2_2021"
    ssl_support_method       = "sni-only"
  }

  restrictions {
    geo_restriction {
      restriction_type = var.cdn_geo_restriction.restriction_type
      locations        = var.cdn_geo_restriction.locations
    }
  }

  # S3 Bucket Origin
  origin {
    domain_name = aws_s3_bucket.assets.bucket_regional_domain_name
    origin_id   = local.cdn_assets_origin_id
    origin_path = "/_assets"

    origin_access_control_id = aws_cloudfront_origin_access_control.assets.id
  }

  # Server Function Origin
  origin {
    domain_name = "${module.server_function.lambda_function_url.url_id}.lambda-url.${var.aws_region}.on.aws"
    origin_id   = local.cdn_server_origin_id

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
    domain_name = "${module.image_optimization_function.lambda_function_url.url_id}.lambda-url.${var.aws_region}.on.aws"
    origin_id   = local.cdn_image_optimization_origin_id

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
    target_origin_id = local.cdn_assets_origin_id

    response_headers_policy_id = aws_cloudfront_response_headers_policy.cdn.id
    cache_policy_id            = data.aws_cloudfront_cache_policy.static.id

    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  ordered_cache_behavior {
    path_pattern     = "/_next/image"
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.cdn_image_optimization_origin_id

    response_headers_policy_id = aws_cloudfront_response_headers_policy.cdn.id
    cache_policy_id            = aws_cloudfront_cache_policy.cdn.id
    origin_request_policy_id = try(
      data.aws_cloudfront_origin_request_policy.cdn[0].id,
      aws_cloudfront_origin_request_policy.cdn[0].id
    )

    compress               = true
    viewer_protocol_policy = "redirect-to-https"

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.host_header.arn
    }
  }

  ordered_cache_behavior {
    path_pattern     = "/_next/data/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = local.cdn_server_origin_id

    response_headers_policy_id = aws_cloudfront_response_headers_policy.cdn.id
    cache_policy_id            = aws_cloudfront_cache_policy.cdn.id
    origin_request_policy_id = try(
      data.aws_cloudfront_origin_request_policy.cdn[0].id,
      aws_cloudfront_origin_request_policy.cdn[0].id
    )

    compress               = true
    viewer_protocol_policy = "redirect-to-https"

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.host_header.arn
    }
  }

  ordered_cache_behavior {
    path_pattern     = "/api/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS", "PUT", "PATCH", "POST", "DELETE"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = local.cdn_server_origin_id

    response_headers_policy_id = aws_cloudfront_response_headers_policy.cdn.id
    cache_policy_id            = aws_cloudfront_cache_policy.cdn.id
    origin_request_policy_id = try(
      data.aws_cloudfront_origin_request_policy.cdn[0].id,
      aws_cloudfront_origin_request_policy.cdn[0].id
    )

    compress               = true
    viewer_protocol_policy = "redirect-to-https"

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.host_header.arn
    }
  }

  ordered_cache_behavior {
    path_pattern     = "/static/*"
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.cdn_assets_origin_id

    response_headers_policy_id = aws_cloudfront_response_headers_policy.cdn.id
    cache_policy_id            = data.aws_cloudfront_cache_policy.static.id

    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  dynamic "ordered_cache_behavior" {
    for_each = toset(var.static_paths)

    content {
      path_pattern     = ordered_cache_behavior.value
      allowed_methods  = ["GET", "HEAD", "OPTIONS"]
      cached_methods   = ["GET", "HEAD", "OPTIONS"]
      target_origin_id = local.cdn_assets_origin_id

      response_headers_policy_id = aws_cloudfront_response_headers_policy.cdn.id
      cache_policy_id            = data.aws_cloudfront_cache_policy.static.id

      compress               = true
      viewer_protocol_policy = "redirect-to-https"
    }
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS", "PUT", "PATCH", "POST", "DELETE"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = local.cdn_server_origin_id

    response_headers_policy_id = aws_cloudfront_response_headers_policy.cdn.id
    cache_policy_id            = aws_cloudfront_cache_policy.cdn.id
    origin_request_policy_id = try(
      data.aws_cloudfront_origin_request_policy.cdn[0].id,
      aws_cloudfront_origin_request_policy.cdn[0].id
    )

    compress               = true
    viewer_protocol_policy = "redirect-to-https"

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.host_header.arn
    }
  }

  tags = merge(
    var.tags,
    {
      Name = var.name
    }
  )
}

resource "aws_s3_bucket" "cdn_logs" {
  bucket           = "${lower(var.slug)}-logs-${data.aws_caller_identity.current.account_id}-${var.aws_region}-an"
  bucket_namespace = "account-regional"
  force_destroy    = true

  tags = var.tags
}

resource "aws_s3_bucket_lifecycle_configuration" "cdn_logs" {
  bucket = aws_s3_bucket.cdn_logs.id

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

resource "aws_s3_bucket_public_access_block" "cdn_logs" {
  bucket = aws_s3_bucket.cdn_logs.id

  block_public_acls       = true
  block_public_policy     = true
  restrict_public_buckets = true
  ignore_public_acls      = true
}

# DNS Records

resource "aws_route53_record" "cdn_a" {
  for_each = var.create_dns_records ? toset(local.cdn_aliases) : toset([])

  zone_id = var.hosted_zone_id
  name    = each.value
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.cdn.domain_name
    zone_id                = aws_cloudfront_distribution.cdn.hosted_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "cdn_aaaa" {
  for_each = var.create_dns_records ? toset(local.cdn_aliases) : toset([])

  zone_id = var.hosted_zone_id
  name    = each.value
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.cdn.domain_name
    zone_id                = aws_cloudfront_distribution.cdn.hosted_zone_id
    evaluate_target_health = true
  }
}

action "aws_cloudfront_create_invalidation" "aws_cloudfront" {
  config {
    distribution_id = aws_cloudfront_distribution.cdn.id
    paths           = ["/*"]
  }
}

resource "terraform_data" "deploy_complete" {
  triggers_replace = var.upload_files ? {
    for f in fileset("${local.opennext_root_build_path}/assets", "**") :
    f => filemd5("${local.opennext_root_build_path}/assets/${f}")
  } : null

  lifecycle {
    action_trigger {
      events    = [before_create, before_update]
      condition = var.cdn_create_invalidation_after_deployment
      actions   = [action.aws_cloudfront_create_invalidation.aws_cloudfront]
    }
  }

  depends_on = [aws_s3_object.assets]
}
