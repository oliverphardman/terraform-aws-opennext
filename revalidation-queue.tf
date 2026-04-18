locals {
  revalidation_kms_key_arn = try(data.aws_kms_key.revalidation[0].arn, aws_kms_key.revalidation[0].arn)
}

data "aws_kms_key" "revalidation" {
  count = var.revalidation_queue_kms_key_arn != null ? 1 : 0

  key_id = var.revalidation_queue_kms_key_arn
}

resource "aws_kms_key" "revalidation" {
  count = var.revalidation_queue_kms_key_arn == null ? 1 : 0

  description             = "${var.name} Revalidation SQS Queue KMS Key"
  deletion_window_in_days = 10

  policy              = data.aws_iam_policy_document.revalidation_kms[0].json
  enable_key_rotation = true

  tags = var.tags
}

data "aws_iam_policy_document" "revalidation_kms" {
  count = var.revalidation_queue_kms_key_arn == null ? 1 : 0

  statement {
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com", "edgelambda.amazonaws.com", "sqs.amazonaws.com"]
    }
  }
}

resource "aws_sqs_queue" "revalidation" {
  name                              = "${var.slug}ISRRevalidation.fifo"
  fifo_queue                        = true
  content_based_deduplication       = true
  receive_wait_time_seconds         = 20
  kms_master_key_id                 = local.revalidation_kms_key_arn
  kms_data_key_reuse_period_seconds = 300

  tags = var.tags
}

resource "aws_lambda_event_source_mapping" "revalidation" {
  event_source_arn = aws_sqs_queue.revalidation.arn
  function_name    = module.revalidation_function.lambda_function.arn
  batch_size       = 5

  tags = var.tags
}
