output "cloudfront_origin_access_control" {
  value = aws_cloudfront_origin_access_control.this
}

output "assets_bucket" {
  value = aws_s3_bucket.this
}
