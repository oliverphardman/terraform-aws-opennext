variable "slug" {
  type        = string
  description = "Prefix for created resource IDs"
}

variable "source_dir" {
  type        = string
  description = "The directory to use as the Lambda deployment package"
}

variable "output_dir" {
  type        = string
  description = "The directory to use to store the Lambda deployment packages"
}

variable "function_name" {
  type        = string
  description = "The name of the Lambda function. Defaults to var.slug"
  default     = null
}

variable "description" {
  type        = string
  description = "A description of the Lambda function"
  default     = "OpenNext Lambda function"
}

variable "memory_size" {
  type        = number
  description = "The memory (in MB) to allocate for the Lambda function"
  default     = 1024
}

variable "timeout" {
  type        = number
  description = "The timeout period for the Lambda function (in seconds)"
  default     = 30
}

variable "environment_variables" {
  type        = map(string)
  description = "The environment variables to be used for the Lambda function"
  default     = {}
}

variable "kms_key_arn" {
  type        = string
  description = "The KMS key to use for encrypting the Lambda function"
  default     = null
}

variable "reserved_concurrent_executions" {
  description = "Concurrency limit for the Lambda function"
  type        = number
  default     = 10
}

variable "iam_policy_statements" {
  type = list(object({
    effect    = string
    actions   = list(string)
    resources = list(string)
  }))
  description = "IAM policy statements to attach to the Lambda function role"
  default     = []
}

variable "create_eventbridge_scheduled_rule" {
  type        = bool
  description = "Toggle to create a scheduled rule in EventBridge to invoke the Lambda function"
  default     = false
}

variable "warmer_schedule_expression" {
  type        = string
  description = "The schedule expression of the warm Lambda trigger rule (if enabled)"
  default     = "rate(5 minutes)"
}

