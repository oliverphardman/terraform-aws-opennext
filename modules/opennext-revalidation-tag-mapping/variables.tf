variable "slug" {
  type        = string
  description = "Prefix for created resource IDs"
}

variable "dynamodb_billing_mode" {
  type        = string
  description = "Billing mode for the DynamoDB table (PROVISIONED or PAY_PER_REQUEST)"
  default     = "PAY_PER_REQUEST"
  validation {
    condition     = contains(["PROVISIONED", "PAY_PER_REQUEST"], var.dynamodb_billing_mode)
    error_message = "Invalid billing mode. Must be either 'PROVISIONED' or 'PAY_PER_REQUEST'."
  }
}
