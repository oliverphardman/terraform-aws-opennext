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
  description = "The path of the OpenNext assets build output directory"
}

variable "cache_path" {
  type        = string
  description = "The path of the OpenNext cache build output directory"
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

variable "upload_assets" {
  type        = bool
  description = "Whether to upload assets to S3. Set to false if you have already uploaded assets or want to manage them separately."
  default     = true
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to all resources."
  default     = {}
}
