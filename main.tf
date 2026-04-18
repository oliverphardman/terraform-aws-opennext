data "aws_caller_identity" "current" {}

module "assets" {
  source = "./modules/assets"

  slug                         = var.slug
  aws_account_id               = data.aws_caller_identity.current.account_id
  aws_region                   = var.aws_region
  use_account_regional_buckets = var.use_account_regional_buckets

  assets_path = "${local.opennext_root_build_path}/assets"
  cache_path  = "${local.opennext_root_build_path}/cache"

  upload_files = var.upload_files

  tags = var.tags
}

resource "aws_dynamodb_table" "cache" {
  name         = "${var.slug}Cache"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "tag"
  range_key    = "path"

  attribute {
    name = "tag"
    type = "S"
  }

  attribute {
    name = "path"
    type = "S"
  }

  attribute {
    name = "revalidatedAt"
    type = "N"
  }

  global_secondary_index {
    name = "revalidate"
    key_schema {
      attribute_name = "path"
      key_type       = "HASH"
    }
    key_schema {
      attribute_name = "revalidatedAt"
      key_type       = "RANGE"
    }
    projection_type = "ALL"
  }

  ttl {
    attribute_name = "revalidatedAt"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = var.cache_pitr_enabled
  }

  tags = var.tags
}

module "revalidation_seeder" {
  source = "./modules/lambda"

  function_name       = "${var.slug}RevalidationSeeder"
  description         = "Seeds the DynamoDB cache table with OpenNext revalidation data"
  memory_size         = 128
  timeout             = 900
  create_function_url = false

  source_dir = "${local.opennext_root_build_path}/dynamodb-provider"
  output_dir = "${local.opennext_root_build_path}/.build/"

  environment_variables = {
    CACHE_DYNAMO_TABLE = aws_dynamodb_table.cache.name
  }

  iam_policy_statements = [
    {
      effect    = "Allow"
      actions   = ["dynamodb:BatchWriteItem", "dynamodb:PutItem", "dynamodb:DescribeTable"]
      resources = [aws_dynamodb_table.cache.arn]
    }
  ]

  tags = var.tags
}

resource "aws_lambda_invocation" "revalidation_seeder" {
  function_name = module.revalidation_seeder.lambda_function.function_name

  input = jsonencode({
    RequestType = "Create"
  })

  triggers = {
    redeployment = module.revalidation_seeder.lambda_function.source_code_hash
  }
}

module "server_function" {
  source = "./modules/lambda"

  function_name = "${var.slug}NextJSServer"
  description   = "Next.js Server"
  memory_size   = 512
  streaming     = var.server_streaming

  source_dir = "${local.opennext_root_build_path}/server-functions/default"
  output_dir = "${local.opennext_root_build_path}/.build/"

  environment_variables = merge({
    CACHE_BUCKET_NAME         = module.assets.assets_bucket.bucket
    CACHE_BUCKET_KEY_PREFIX   = "_cache"
    CACHE_BUCKET_REGION       = var.aws_region
    CACHE_DYNAMO_TABLE        = aws_dynamodb_table.cache.name
    REVALIDATION_QUEUE_URL    = module.revalidation_queue.queue.url
    REVALIDATION_QUEUE_REGION = var.aws_region
  }, var.runtime_environment_variables)

  iam_policy_statements = concat([
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
      resources = [aws_dynamodb_table.cache.arn, "${aws_dynamodb_table.cache.arn}/index/*"]
    }
  ], var.runtime_iam_execution_policy_statements)

  tags = var.tags
}

module "image_optimization_function" {
  source = "./modules/lambda"

  function_name = "${var.slug}NextJSImageOptimization"
  description   = "Next.js Image Optimization"
  memory_size   = 512

  source_dir = "${local.opennext_root_build_path}/image-optimization-function/"
  output_dir = "${local.opennext_root_build_path}/.build/"

  environment_variables = {
    BUCKET_NAME       = module.assets.assets_bucket.bucket
    BUCKET_KEY_PREFIX = "_assets"
  }

  iam_policy_statements = concat([
    {
      effect    = "Allow"
      actions   = ["s3:ListBucket", "s3:GetObject"]
      resources = [module.assets.assets_bucket.arn, "${module.assets.assets_bucket.arn}/*"]
    }
  ], var.image_optimization_iam_execution_policy_statements)

  tags = var.tags
}

module "revalidation_function" {
  source = "./modules/lambda"

  function_name = "${var.slug}NextJSRevalidation"
  description   = "Next.js ISR Revalidation Function"
  memory_size   = 128

  source_dir = "${local.opennext_root_build_path}/revalidation-function/"
  output_dir = "${local.opennext_root_build_path}/.build/"

  environment_variables = {
    CACHE_BUCKET_NAME       = module.assets.assets_bucket.bucket
    CACHE_BUCKET_KEY_PREFIX = "_cache"
    CACHE_BUCKET_REGION     = var.aws_region
    CACHE_DYNAMO_TABLE      = aws_dynamodb_table.cache.name
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
      resources = [aws_dynamodb_table.cache.arn, "${aws_dynamodb_table.cache.arn}/index/*"]
    }
  ]

  tags = var.tags
}

module "revalidation_queue" {
  source = "./modules/revalidation-queue"

  app_name = var.name
  slug     = var.slug

  aws_account_id            = data.aws_caller_identity.current.account_id
  revalidation_function_arn = module.revalidation_function.lambda_function.arn

  tags = var.tags
}

module "warmer_function" {
  count  = var.warmer_function_enabled ? 1 : 0
  source = "./modules/lambda"

  function_name = "${var.slug}NextJSWarmer"
  description   = "Next.js Warmer Function"
  memory_size   = 128

  source_dir = "${local.opennext_root_build_path}/warmer-function/"
  output_dir = "${local.opennext_root_build_path}/.build/"

  environment_variables = {
    WARM_PARAMS = jsonencode([{
      function    = module.server_function.lambda_function.function_name
      concurrency = 1
    }])
  }

  url_authorization_type = "AWS_IAM"

  iam_policy_statements = [
    {
      effect    = "Allow"
      actions   = ["lambda:InvokeFunction"]
      resources = [module.server_function.lambda_function.arn]
    }
  ]

  tags = var.tags
}

resource "aws_cloudwatch_event_rule" "warmer" {
  count = var.warmer_function_enabled ? 1 : 0

  name                = "${var.slug}NextJSWarmerScheduledRule"
  schedule_expression = "rate(5 minutes)"

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "warmer" {
  count = var.warmer_function_enabled ? 1 : 0

  arn  = module.warmer_function[0].lambda_function.arn
  rule = aws_cloudwatch_event_rule.warmer[0].name
}

resource "aws_lambda_permission" "warmer" {
  count = var.warmer_function_enabled ? 1 : 0

  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = module.warmer_function[0].lambda_function.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.warmer[0].arn
}

module "cloudfront" {
  source         = "./modules/cdn"
  slug           = var.slug
  aws_account_id = data.aws_caller_identity.current.account_id
  aws_region     = var.aws_region

  app_name                        = var.name
  aliases                         = var.enable_www_alias ? [var.deployment_domain, "www.${var.deployment_domain}"] : [var.deployment_domain]
  acm_certificate_arn             = var.acm_arn
  assets_paths                    = var.static_paths
  custom_waf                      = var.waf_arn != null ? { arn = var.waf_arn } : null
  route53_hosted_zone_id          = var.hosted_zone_id
  create_dns_records              = var.create_dns_records
  assets_origin_access_control_id = module.assets.cloudfront_origin_access_control.id
  assets_bucket_name              = module.assets.assets_bucket.bucket
  server_function_role_arn        = module.server_function.lambda_role.arn
  price_class                     = var.cdn_price_class

  origins = {
    assets_bucket               = module.assets.assets_bucket.bucket_regional_domain_name
    server_function             = "${module.server_function.lambda_function_url.url_id}.lambda-url.${var.aws_region}.on.aws"
    image_optimization_function = "${module.image_optimization_function.lambda_function_url.url_id}.lambda-url.${var.aws_region}.on.aws"
  }

  tags = var.tags
}
