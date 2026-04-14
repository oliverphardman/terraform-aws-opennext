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

# TerraNext

module "terranext" {
  source  = "terranext-dev/opennext/aws"
  version = "~> 1.0"

  name                = "My Website"
  slug                = "my-website"
  aws_region          = local.region
  opennext_build_path = "../.open-next"
  deployment_domain   = local.domain
  acm_arn             = aws_acm_certificate_validation.this.certificate_arn
  hosted_zone_id      = data.aws_route53_zone.this.zone_id
  create_dns_records  = true
}
