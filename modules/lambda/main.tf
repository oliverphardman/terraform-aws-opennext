resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = 365

  tags = var.tags
}

resource "aws_lambda_function" "this" {
  filename         = data.archive_file.this.output_path
  source_code_hash = data.archive_file.this.output_base64sha256

  function_name = var.function_name
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
  count              = var.create_function_url ? 1 : 0
  function_name      = aws_lambda_function.this.function_name
  authorization_type = var.url_authorization_type
  invoke_mode        = var.streaming ? "RESPONSE_STREAM" : "BUFFERED"
}

resource "aws_lambda_permission" "this" {
  count         = var.create_function_url && var.url_authorization_type == "NONE" ? 1 : 0
  statement_id  = "FunctionURLAllowInvokeAction"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "*"
}

resource "aws_lambda_permission" "this_url" {
  count                  = var.create_function_url && var.url_authorization_type == "NONE" ? 1 : 0
  statement_id           = "FunctionURLAllowPublicAccess"
  function_name          = aws_lambda_function.this.function_name
  principal              = "*"
  function_url_auth_type = "NONE"

  action = "lambda:InvokeFunctionUrl"
}
