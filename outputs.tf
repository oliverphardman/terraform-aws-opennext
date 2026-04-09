output "cloudfront_distribution_id" {
  value = module.cloudfront.cloudfront_distribution.id
}

output "cloudfront_distribution_domain_name" {
  value = module.cloudfront.cloudfront_distribution.domain_name
}