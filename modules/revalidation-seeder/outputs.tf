output "lambda_function" {
  description = "The Lambda function used to seed the DynamoDB cache table"
  value       = aws_lambda_function.this
}
