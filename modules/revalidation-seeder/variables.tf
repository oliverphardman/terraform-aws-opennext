variable "slug" {
  type        = string
  description = "Prefix for created resource IDs"
}

variable "source_dir" {
  type        = string
  description = "Path to the OpenNext dynamodb-provider bundle"
}

variable "output_dir" {
  type        = string
  description = "The directory to store the Lambda deployment package"
}

variable "table_name" {
  type        = string
  description = "The name of the DynamoDB cache table to seed"
}

variable "table_arn" {
  type        = string
  description = "The ARN of the DynamoDB cache table to seed"
}
