data "archive_file" "this" {
  type = "zip"

  source_dir  = var.source_dir
  output_path = "${var.output_dir}${var.slug}-revalidation-seeder.zip"
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${var.slug}RevalidationSeeder"
  retention_in_days = 14

  tags = var.tags
}

resource "aws_iam_role" "this" {
  name               = "${var.slug}RevalidationSeederRole"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  tags = var.tags
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "permission" {
  statement {
    effect    = "Allow"
    actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["arn:aws:logs:*:*:*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["dynamodb:BatchWriteItem", "dynamodb:PutItem", "dynamodb:DescribeTable"]
    resources = [var.table_arn]
  }
}

resource "aws_iam_policy" "this" {
  name   = "${var.slug}RevalidationSeederPolicy"
  policy = data.aws_iam_policy_document.permission.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "this" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.this.arn
}

resource "aws_lambda_function" "this" {
  filename         = data.archive_file.this.output_path
  source_code_hash = data.archive_file.this.output_base64sha256

  function_name = "${var.slug}RevalidationSeeder"
  description   = "Seeds the DynamoDB cache table with OpenNext revalidation data"

  role = aws_iam_role.this.arn

  handler       = "index.handler"
  runtime       = "nodejs24.x"
  architectures = ["arm64"]
  timeout       = 900
  memory_size   = 128

  environment {
    variables = {
      CACHE_DYNAMO_TABLE = var.table_name
    }
  }

  tags = var.tags

  depends_on = [aws_cloudwatch_log_group.this]
}

resource "aws_lambda_invocation" "this" {
  function_name = aws_lambda_function.this.function_name

  input = jsonencode({
    RequestType = "Create"
  })

  triggers = {
    redeployment = data.archive_file.this.output_base64sha256
  }
}
