output "cloudfront_origin_access_control" {
  description = "The CloudFront Origin Access Control for the assets S3 bucket"
  value       = aws_cloudfront_origin_access_control.this
}

output "assets_bucket" {
  description = "The S3 bucket used for static assets and cache storage"
  value       = aws_s3_bucket.this
}
