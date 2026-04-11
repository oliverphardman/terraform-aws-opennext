output "lambda_function" {
  value = aws_lambda_function.this
}

output "lambda_function_url" {
  value = aws_lambda_function_url.this
}

output "cloudfront_origin_access_control" {
  value = aws_cloudfront_origin_access_control.this
}

output "lambda_role" {
  value = aws_iam_role.this
}

output "log_group" {
  value = aws_cloudwatch_log_group.this
}
