output "table" {
  description = "DynamoDB cache table"
  value       = aws_dynamodb_table.this
}

output "table_name" {
  description = "DynamoDB cache table name"
  value       = aws_dynamodb_table.this.name
}

output "table_arn" {
  description = "DynamoDB cache table ARN"
  value       = aws_dynamodb_table.this.arn
}
