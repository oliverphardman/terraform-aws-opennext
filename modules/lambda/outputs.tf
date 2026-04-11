output "lambda_function" {
  description = "The Lambda function resource"
  value       = aws_lambda_function.this
}

output "lambda_function_url" {
  description = "The Lambda Function URL resource"
  value       = aws_lambda_function_url.this
}

output "cloudfront_origin_access_control" {
  description = "The CloudFront Origin Access Control for the Lambda Function URL"
  value       = aws_cloudfront_origin_access_control.this
}

output "lambda_role" {
  description = "The IAM role attached to the Lambda function"
  value       = aws_iam_role.this
}

output "log_group" {
  description = "The CloudWatch log group for the Lambda function"
  value       = aws_cloudwatch_log_group.this
}
