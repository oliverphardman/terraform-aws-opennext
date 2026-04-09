variable "slug" {
  type        = string
  description = "Prefix for resource names"
}

variable "dynamodb_cache_billing_mode" {
  type        = string
  description = "Billing mode for the DynamoDB cache table. Can be either PROVISIONED or PAY_PER_REQUEST."
  default     = "PAY_PER_REQUEST"

  validation {
    condition     = contains(["PROVISIONED", "PAY_PER_REQUEST"], var.dynamodb_cache_billing_mode)
    error_message = "dynamodb_cache_billing_mode must be either PROVISIONED or PAY_PER_REQUEST"
  }
}