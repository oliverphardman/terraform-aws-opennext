data "aws_caller_identity" "current" {}

module "assets" {
  source = "./modules/opennext-assets"

  slug                         = var.slug
  aws_account_id               = data.aws_caller_identity.current.account_id
  aws_region                   = var.aws_region
  use_account_regional_buckets = var.use_account_regional_buckets

  assets_path               = "${local.opennext_abs_path}/assets"
  static_asset_cache_config = var.static_asset_cache_config
}

module "cache_table" {
  source = "./modules/opennext-cache-table"
  slug   = var.slug
}

module "revalidation_seeder" {
  source = "./modules/opennext-revalidation-seeder"

  slug       = var.slug
  source_dir = "${local.opennext_abs_path}/dynamodb-provider"
  output_dir = "${local.opennext_abs_path}/.build/"
  table_name = module.cache_table.table_name
  table_arn  = module.cache_table.table_arn
}

module "server_function" {
  source = "./modules/opennext-lambda"

  slug        = var.slug
  description = "Next.js Server"
  memory_size = 512
  streaming   = var.server_streaming

  source_dir = "${local.opennext_abs_path}/server-functions/default"
  output_dir = "${local.opennext_abs_path}/.build/"

  environment_variables = merge({
    CACHE_BUCKET_NAME         = module.assets.assets_bucket.bucket
    CACHE_BUCKET_KEY_PREFIX   = "_cache"
    CACHE_BUCKET_REGION       = var.aws_region
    CACHE_DYNAMO_TABLE        = module.cache_table.table_name
    REVALIDATION_QUEUE_URL    = module.revalidation_queue.queue.url
    REVALIDATION_QUEUE_REGION = var.aws_region
  }, var.runtime_environment_variables)

  iam_policy_statements = [
    {
      effect    = "Allow"
      actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
      resources = [module.assets.assets_bucket.arn, "${module.assets.assets_bucket.arn}/*"]
    },
    {
      effect    = "Allow"
      actions   = ["sqs:SendMessage"]
      resources = [module.revalidation_queue.queue.arn]
    },
    {
      effect    = "Allow"
      actions   = ["kms:GenerateDataKey", "kms:Decrypt"]
      resources = [module.revalidation_queue.queue_kms_key.arn]
    },
    {
      effect    = "Allow"
      actions   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:DeleteItem", "dynamodb:Query", "dynamodb:Scan", "dynamodb:BatchWriteItem"]
      resources = [module.cache_table.table_arn, "${module.cache_table.table_arn}/index/*"]
    }
  ]
}

module "image_optimization_function" {
  source = "./modules/opennext-lambda"

  slug                           = "${var.slug}-nextjs-image-optimization"
  description                    = "Next.js Image Optimization"
  memory_size                    = 512
  reserved_concurrent_executions = 3

  source_dir = "${local.opennext_abs_path}/image-optimization-function/"
  output_dir = "${local.opennext_abs_path}/.build/"

  environment_variables = {
    BUCKET_NAME       = module.assets.assets_bucket.bucket
    BUCKET_KEY_PREFIX = "_assets"
  }

  iam_policy_statements = [
    {
      effect    = "Allow"
      actions   = ["s3:ListBucket", "s3:GetObject"]
      resources = [module.assets.assets_bucket.arn, "${module.assets.assets_bucket.arn}/*"]
    }
  ]
}

module "revalidation_function" {
  source = "./modules/opennext-lambda"

  slug                           = "${var.slug}-nextjs-revalidation"
  description                    = "Next.js ISR Revalidation Function"
  memory_size                    = 128
  reserved_concurrent_executions = 3

  source_dir = "${local.opennext_abs_path}/revalidation-function/"
  output_dir = "${local.opennext_abs_path}/.build/"

  environment_variables = {
    CACHE_BUCKET_NAME       = module.assets.assets_bucket.bucket
    CACHE_BUCKET_KEY_PREFIX = "cache"
    CACHE_BUCKET_REGION     = var.aws_region
    CACHE_DYNAMO_TABLE      = module.cache_table.table_name
  }

  iam_policy_statements = [
    {
      effect    = "Allow"
      actions   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
      resources = [module.revalidation_queue.queue.arn]
    },
    {
      effect    = "Allow"
      actions   = ["kms:Decrypt", "kms:DescribeKey"]
      resources = [module.revalidation_queue.queue_kms_key.arn]
    },
    {
      effect    = "Allow"
      actions   = ["s3:ListBucket", "s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
      resources = [module.assets.assets_bucket.arn, "${module.assets.assets_bucket.arn}/*"]
    },
    {
      effect    = "Allow"
      actions   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:DeleteItem", "dynamodb:Query", "dynamodb:BatchWriteItem"]
      resources = [module.cache_table.table_arn, "${module.cache_table.table_arn}/index/*"]
    }
  ]
}

module "revalidation_queue" {
  source = "./modules/opennext-revalidation-queue"

  slug = "${var.slug}-revalidation-queue"

  aws_account_id            = data.aws_caller_identity.current.account_id
  revalidation_function_arn = module.revalidation_function.lambda_function.arn
}

module "warmer_function" {
  count  = var.warmer_function_enabled ? 1 : 0
  source = "./modules/opennext-lambda"

  slug                              = "${var.slug}-nextjs-warmer"
  description                       = "Next.js Warmer Function"
  memory_size                       = 128
  reserved_concurrent_executions    = 3
  create_eventbridge_scheduled_rule = true

  source_dir = "${local.opennext_abs_path}/warmer-function/"
  output_dir = "${local.opennext_abs_path}/.build/"

  environment_variables = {
    FUNCTION_NAME = module.server_function.lambda_function.function_name
    CONCURRENCY   = 1
  }

  iam_policy_statements = [
    {
      effect    = "Allow"
      actions   = ["lambda:InvokeFunction"]
      resources = [module.server_function.lambda_function.arn]
    }
  ]
}

module "cloudfront" {
  source         = "./modules/opennext-cloudfront"
  slug           = var.slug
  aws_account_id = data.aws_caller_identity.current.account_id
  aws_region     = var.aws_region

  name                            = var.name
  aliases                         = [var.deployment_domain, "www.${var.deployment_domain}"]
  enable_www_alias                = var.enable_www_alias
  acm_certificate_arn             = var.acm_arn
  assets_paths                    = var.static_paths
  custom_waf                      = var.waf_arn != null ? { arn = var.waf_arn } : null
  route53_hosted_zone_id          = var.hosted_zone_id
  assets_origin_access_control_id = module.assets.cloudfront_origin_access_control.id
  assets_bucket_name              = module.assets.assets_bucket.bucket
  server_function_role_arn        = module.server_function.lambda_role.arn

  server_function_oac_id             = module.server_function.cloudfront_origin_access_control.id
  image_optimization_function_oac_id = module.image_optimization_function.cloudfront_origin_access_control.id

  origins = {
    assets_bucket               = module.assets.assets_bucket.bucket_regional_domain_name
    server_function             = "${module.server_function.lambda_function_url.url_id}.lambda-url.${var.aws_region}.on.aws"
    image_optimization_function = "${module.image_optimization_function.lambda_function_url.url_id}.lambda-url.${var.aws_region}.on.aws"
  }
}

resource "aws_lambda_permission" "server" {
  statement_id  = "AllowCloudFrontServicePrincipal"
  action        = "lambda:InvokeFunctionUrl"
  function_name = module.server_function.lambda_function.function_name
  principal     = "cloudfront.amazonaws.com"
  source_arn    = module.cloudfront.cloudfront_distribution.arn
}

resource "aws_lambda_permission" "image_optimization" {
  statement_id  = "AllowCloudFrontServicePrincipal"
  action        = "lambda:InvokeFunctionUrl"
  function_name = module.image_optimization_function.lambda_function.function_name
  principal     = "cloudfront.amazonaws.com"
  source_arn    = module.cloudfront.cloudfront_distribution.arn
}
