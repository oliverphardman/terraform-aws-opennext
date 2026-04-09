provider "aws" {
  region = local.region
}

# DNS

data "aws_route53_zone" "this" {
  name = local.domain
}

# ACM

resource "aws_acm_certificate" "this" {
  region = "us-east-1"

  domain_name               = local.domain
  subject_alternative_names = ["*.${local.domain}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "validation" {
  for_each = {
    for dvo in aws_acm_certificate.this.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = data.aws_route53_zone.this.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60

  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "this" {
  region = "us-east-1"

  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [for record in aws_route53_record.validation : record.fqdn]
}

# WAF

resource "aws_wafv2_web_acl" "this" {
  name  = "my-website-waf"
  scope = "CLOUDFRONT"

  default_action {
    allow {}
  }

  rule {
    name     = "aws-managed-common"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesCommonRuleSet"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "my-website-waf"
    sampled_requests_enabled   = true
  }
}

# Terranext

module "terranext" {
  source = "./modules/terranext"

  name                = "My Website"
  slug                = "my-website"
  aws_region          = local.region
  opennext_build_path = ".open-next"
  deployment_domain   = local.domain
  acm_arn             = aws_acm_certificate_validation.this.certificate_arn
  hosted_zone_id      = data.aws_route53_zone.this.zone_id
  waf_arn             = aws_wafv2_web_acl.this.arn

  runtime_environment_variables = {
    DATABASE_URL     = "postgresql://localhost:5432/mydb"
    NEXT_PUBLIC_SITE = "https://${local.domain}"
  }

  warmer_function_enabled      = true
  enable_www_alias             = true
  use_account_regional_buckets = true
  static_asset_cache_config    = "public,max-age=0,s-maxage=31536000,must-revalidate"

  static_paths = [
    "/favicon.ico",
    "/icon.svg",
    "/icon.png",
    "/llms.txt",
    "/llms-full.txt",
    "/.well-known/*",
    "/images/*",
    "/fonts/*",
  ]
}
