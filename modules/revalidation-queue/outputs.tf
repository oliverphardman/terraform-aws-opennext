output "queue" {
  description = "The SQS FIFO queue used for ISR revalidation"
  value       = aws_sqs_queue.this
}

output "queue_kms_key" {
  description = "The KMS key used to encrypt the revalidation queue"
  value       = try(aws_kms_key.this[0], data.aws_kms_key.this[0])
}
