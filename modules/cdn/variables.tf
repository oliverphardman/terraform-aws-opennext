variable "slug" {
  type        = string
  description = "Prefix for created resource IDs"
}

variable "app_name" {
  type        = string
  description = "The name of the CloudFront distribution"
}

variable "aws_account_id" {
  type        = string
  description = "The AWS account ID, used for account-regional bucket naming"
}

variable "aws_region" {
  type        = string
  description = "The AWS region, used for account-regional bucket naming"
}

variable "acm_certificate_arn" {
  description = "The ARN of the ACM certificate for the CloudFront distribution"
  type        = string
}

variable "price_class" {
  type        = string
  description = "The price class to use for the distribution"
  validation {
    condition     = contains(["PriceClass_200", "PriceClass_100", "PriceClass_All"], var.price_class)
    error_message = "Valid values for price_class are: `PriceClass_200`, `PriceClass_100` and `PriceClass_All`."
  }
  default = "PriceClass_All"
}

variable "assets_bucket_name" {
  type        = string
  description = "The name of the assets S3 bucket"
}

variable "assets_origin_access_control_id" {
  type        = string
  description = "The ID of the CloudFront Origin Access Control for the assets S3 bucket"
}

variable "origins" {
  type = object({
    assets_bucket               = string
    server_function             = string
    image_optimization_function = string
  })
  description = "Origin domain names for CloudFront"
}

variable "server_function_role_arn" {
  type        = string
  description = "The IAM role ARN of the Next.js server Lambda function"
}

variable "assets_paths" {
  type        = list(string)
  description = "Paths to expose as static assets (i.e. /images/*)"
}

variable "aliases" {
  type        = list(string)
  description = "The aliases (domain names) to be used for the Next.js application"
}

variable "custom_headers" {
  type = list(object({
    header   = string
    override = bool
    value    = string
  }))
  description = "Add custom headers to the CloudFront response headers policy"
  default     = []
}

variable "cors" {
  description = "CORS (Cross-Origin Resource Sharing) configuration for the CloudFront distribution"
  type = object({
    allow_credentials = bool,
    allow_headers     = list(string)
    allow_methods     = list(string)
    allow_origins     = list(string)
    origin_override   = bool
  })
  default = {
    allow_credentials = false,
    allow_headers     = ["*"],
    allow_methods     = ["ALL"],
    allow_origins     = ["*"],
    origin_override   = true
  }
}

variable "hsts" {
  description = "HSTS (HTTP Strict Transport Security) configuration for the CloudFront distribution"
  type = object({
    access_control_max_age_sec = number
    include_subdomains         = bool
    override                   = bool
    preload                    = bool
  })
  default = {
    access_control_max_age_sec = 31536000
    include_subdomains         = true
    override                   = true
    preload                    = true
  }
}

variable "custom_waf" {
  description = "Configuration for an externally created AWS WAF. No WAF will be associated if left blank."
  type = object({
    arn = string
  })
  default = null
}

variable "origin_request_policy" {
  description = "Custom origin request policy for the CloudFront distribution. When null, the managed AllViewerExceptHostHeader policy is used."
  type = object({
    cookies_config = object({
      cookie_behavior = string
      items           = list(string)
    })
    headers_config = object({
      header_behavior = string
      items           = optional(list(string))
    })
    query_strings_config = object({
      query_string_behavior = string
      items                 = optional(list(string))
    })
  })
  default = null
}

variable "cache_policy" {
  description = "Cache policy configuration for the CloudFront distribution"
  type = object({
    default_ttl                   = number
    min_ttl                       = number
    max_ttl                       = number
    enable_accept_encoding_gzip   = bool
    enable_accept_encoding_brotli = bool
    cookies_config = object({
      cookie_behavior = string
      items           = optional(list(string))
    })
    headers_config = object({
      header_behavior = string
      items           = optional(list(string))
    })
    query_strings_config = object({
      query_string_behavior = string
      items                 = optional(list(string))
    })
  })
  default = {
    default_ttl                   = 0
    min_ttl                       = 0
    max_ttl                       = 31536000
    enable_accept_encoding_brotli = true
    enable_accept_encoding_gzip   = true
    cookies_config = {
      cookie_behavior = "none"
      items           = []
    }
    headers_config = {
      header_behavior = "whitelist"
      items           = []
    }
    query_strings_config = {
      query_string_behavior = "all"
      items                 = []
    }
  }
}

variable "geo_restriction" {
  description = "The georestriction configuration for the CloudFront distribution"
  type = object({
    restriction_type = string
    locations        = list(string)
  })
  default = {
    restriction_type = "none"
    locations        = []
  }
}

variable "remove_headers_config" {
  description = "Response header removal configuration for the CloudFront distribution"
  type = object({
    items = list(string)
  })
  default = {
    items = []
  }
}

variable "route53_hosted_zone_id" {
  description = "The ID of the Route 53 hosted zone to create DNS records in. If left blank, no DNS records will be created."
  type        = string
  default     = null
}

variable "create_dns_records" {
  description = "Whether to create Route 53 DNS records. Must be a static value known at plan time."
  type        = bool
  default     = false
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to all resources."
  default     = {}
}
