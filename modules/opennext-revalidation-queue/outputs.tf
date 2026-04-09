output "queue" {
  value = aws_sqs_queue.this
}

output "queue_kms_key" {
  value = try(aws_kms_key.this[0], data.aws_kms_key.this[0])
}
