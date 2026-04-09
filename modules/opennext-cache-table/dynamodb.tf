resource "aws_dynamodb_table" "this" {
  name         = "${var.slug}Cache"
  billing_mode = var.dynamodb_cache_billing_mode
  hash_key     = "Path"
  range_key    = "RevalidatedAt"

  attribute {
    name = "Path"
    type = "S"
  }

  attribute {
    name = "RevalidatedAt"
    type = "N"
  }

  ttl {
    attribute_name = "ExpireAt"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = true
  }
}
