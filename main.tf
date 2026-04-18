data "aws_caller_identity" "current" {}

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
  description         = "Seeds the DynamoDB cache table with OpenNext revalidation data for ${var.name}"
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
  description   = "Next.js server for ${var.name}"
  memory_size   = var.server_memory_size
  streaming     = var.server_streaming

  source_dir = "${local.opennext_root_build_path}/server-functions/default"
  output_dir = "${local.opennext_root_build_path}/.build/"

  environment_variables = merge({
    CACHE_BUCKET_NAME         = aws_s3_bucket.assets.bucket
    CACHE_BUCKET_KEY_PREFIX   = "_cache"
    CACHE_BUCKET_REGION       = var.aws_region
    CACHE_DYNAMO_TABLE        = aws_dynamodb_table.cache.name
    REVALIDATION_QUEUE_URL    = aws_sqs_queue.revalidation.url
    REVALIDATION_QUEUE_REGION = var.aws_region
  }, var.server_environment_variables)

  iam_policy_statements = concat([
    {
      effect    = "Allow"
      actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
      resources = [aws_s3_bucket.assets.arn, "${aws_s3_bucket.assets.arn}/*"]
    },
    {
      effect    = "Allow"
      actions   = ["sqs:SendMessage"]
      resources = [aws_sqs_queue.revalidation.arn]
    },
    {
      effect    = "Allow"
      actions   = ["kms:GenerateDataKey", "kms:Decrypt"]
      resources = [local.revalidation_kms_key_arn]
    },
    {
      effect    = "Allow"
      actions   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:DeleteItem", "dynamodb:Query", "dynamodb:Scan", "dynamodb:BatchWriteItem"]
      resources = [aws_dynamodb_table.cache.arn, "${aws_dynamodb_table.cache.arn}/index/*"]
    }
  ], var.server_iam_execution_policy_statements)

  tags = var.tags
}

module "image_optimization_function" {
  source = "./modules/lambda"

  function_name = "${var.slug}NextJSImageOptimization"
  description   = "Next.js image optimization function for ${var.name}"
  memory_size   = 512

  source_dir = "${local.opennext_root_build_path}/image-optimization-function/"
  output_dir = "${local.opennext_root_build_path}/.build/"

  environment_variables = {
    BUCKET_NAME       = aws_s3_bucket.assets.bucket
    BUCKET_KEY_PREFIX = "_assets"
  }

  iam_policy_statements = concat([
    {
      effect    = "Allow"
      actions   = ["s3:ListBucket", "s3:GetObject"]
      resources = [aws_s3_bucket.assets.arn, "${aws_s3_bucket.assets.arn}/*"]
    }
  ], var.image_optimization_iam_execution_policy_statements)

  tags = var.tags
}

module "revalidation_function" {
  source = "./modules/lambda"

  function_name = "${var.slug}NextJSRevalidation"
  description   = "Next.js ISR revalidation function for ${var.name}"
  memory_size   = 128

  source_dir = "${local.opennext_root_build_path}/revalidation-function/"
  output_dir = "${local.opennext_root_build_path}/.build/"

  environment_variables = {
    CACHE_BUCKET_NAME       = aws_s3_bucket.assets.bucket
    CACHE_BUCKET_KEY_PREFIX = "_cache"
    CACHE_BUCKET_REGION     = var.aws_region
    CACHE_DYNAMO_TABLE      = aws_dynamodb_table.cache.name
  }

  iam_policy_statements = [
    {
      effect    = "Allow"
      actions   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
      resources = [aws_sqs_queue.revalidation.arn]
    },
    {
      effect    = "Allow"
      actions   = ["kms:Decrypt", "kms:DescribeKey"]
      resources = [local.revalidation_kms_key_arn]
    },
    {
      effect    = "Allow"
      actions   = ["s3:ListBucket", "s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
      resources = [aws_s3_bucket.assets.arn, "${aws_s3_bucket.assets.arn}/*"]
    },
    {
      effect    = "Allow"
      actions   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:DeleteItem", "dynamodb:Query", "dynamodb:BatchWriteItem"]
      resources = [aws_dynamodb_table.cache.arn, "${aws_dynamodb_table.cache.arn}/index/*"]
    }
  ]

  tags = var.tags
}

module "warmer_function" {
  count  = var.warmer_function_enabled ? 1 : 0
  source = "./modules/lambda"

  function_name = "${var.slug}NextJSWarmer"
  description   = "Warmer function for ${var.name}"
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
