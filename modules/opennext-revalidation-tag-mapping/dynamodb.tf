resource "aws_dynamodb_table" "this" {
  name         = "${var.slug}RevalidationTagMapping"
  billing_mode = var.dynamodb_billing_mode
  hash_key     = "Tag"
  range_key    = "Path"

  attribute {
    name = "Tag"
    type = "S"
  }

  attribute {
    name = "Path"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }
}
