output "cloudfront_distribution" {
  description = "The CloudFront distribution resource"
  value       = aws_cloudfront_distribution.this
}
