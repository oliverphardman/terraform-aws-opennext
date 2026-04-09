variable "slug" {
  type        = string
  description = "Prefix for created resource IDs"
}

variable "aws_account_id" {
  type        = string
  description = "The AWS account ID, used for account-regional bucket naming"
}

variable "aws_region" {
  type        = string
  description = "The AWS region, used for account-regional bucket naming"
}

variable "use_account_regional_buckets" {
  type        = bool
  description = "Whether to use account-regional namespace for S3 buckets"
  default     = true
}

variable "assets_path" {
  type        = string
  description = "The path of the open-next static assets"
}

variable "static_asset_cache_config" {
  type        = string
  description = "Static asset cache config"
}

variable "logging_config" {
  type = object({
    target_bucket = string
    target_prefix = string
  })
  default = null
}

variable "replication_configuration" {
  description = "Replication Configuration for the S3 bucket"
  default     = null
  type = object({
    role = string
    rules = list(object({
      id     = string
      status = string
      filters = list(object({
        prefix = string
      }))
      destination = object({
        bucket        = string
        storage_class = string
      })
    }))
  })
}
