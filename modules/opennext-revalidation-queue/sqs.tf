locals {
  kms_key_arn = try(data.aws_kms_key.this[0].arn, aws_kms_key.this[0].arn)
}

resource "aws_sqs_queue" "this" {
  name                              = "${var.slug}-isr-revalidation.fifo"
  fifo_queue                        = true
  content_based_deduplication       = true
  receive_wait_time_seconds         = 20
  kms_master_key_id                 = local.kms_key_arn
  kms_data_key_reuse_period_seconds = 300
}

resource "aws_lambda_event_source_mapping" "this" {
  event_source_arn = aws_sqs_queue.this.arn
  function_name    = var.revalidation_function_arn
  batch_size       = 5
}
