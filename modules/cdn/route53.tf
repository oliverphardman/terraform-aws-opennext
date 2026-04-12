resource "aws_route53_record" "a" {
  for_each = var.create_dns_records ? toset(var.aliases) : toset([])

  zone_id = var.route53_hosted_zone_id
  name    = each.value
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.this.domain_name
    zone_id                = aws_cloudfront_distribution.this.hosted_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "aaaa" {
  for_each = var.create_dns_records ? toset(var.aliases) : toset([])

  zone_id = var.route53_hosted_zone_id
  name    = each.value
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.this.domain_name
    zone_id                = aws_cloudfront_distribution.this.hosted_zone_id
    evaluate_target_health = true
  }
}
