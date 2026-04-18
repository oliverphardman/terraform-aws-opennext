output "lambda_function" {
  description = "The Lambda function resource"
  value       = aws_lambda_function.this
}

output "lambda_function_url" {
  description = "The Lambda Function URL resource"
  value       = var.create_function_url ? aws_lambda_function_url.this[0] : null
}

output "lambda_role" {
  description = "The IAM role attached to the Lambda function"
  value       = aws_iam_role.this
}

output "log_group" {
  description = "The CloudWatch log group for the Lambda function"
  value       = aws_cloudwatch_log_group.this
}
