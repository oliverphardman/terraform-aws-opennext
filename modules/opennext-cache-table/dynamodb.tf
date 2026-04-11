resource "aws_dynamodb_table" "this" {
  name         = "${var.slug}Cache"
  billing_mode = var.dynamodb_cache_billing_mode
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
    enabled = true
  }
}