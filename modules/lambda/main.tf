locals {
  function_name = coalesce(var.function_name, var.slug)
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${local.function_name}"
  retention_in_days = 365

  tags = var.tags
}

resource "aws_lambda_function" "this" {
  filename         = data.archive_file.this.output_path
  source_code_hash = data.archive_file.this.output_base64sha256

  function_name = local.function_name
  description   = var.description

  role = aws_iam_role.this.arn

  handler       = "index.handler"
  runtime       = "nodejs24.x"
  architectures = ["arm64"]

  kms_key_arn                    = var.kms_key_arn
  reserved_concurrent_executions = var.reserved_concurrent_executions

  memory_size = var.memory_size
  timeout     = var.timeout

  tracing_config {
    mode = "Active"
  }

  environment {
    variables = var.environment_variables
  }

  tags = var.tags

  depends_on = [aws_cloudwatch_log_group.this]
}

resource "aws_lambda_function_url" "this" {
  function_name      = aws_lambda_function.this.function_name
  authorization_type = "AWS_IAM"
  invoke_mode        = var.streaming ? "RESPONSE_STREAM" : "BUFFERED"
}

resource "aws_cloudfront_origin_access_control" "this" {
  name                              = "${var.slug}-lambda-oac"
  description                       = "CloudFront OAC for ${aws_lambda_function.this.function_name}"
  origin_access_control_origin_type = "lambda"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

