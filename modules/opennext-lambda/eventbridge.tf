resource "aws_cloudwatch_event_rule" "this" {
  count = var.create_eventbridge_scheduled_rule ? 1 : 0

  name                = "${var.slug}ScheduledRule"
  schedule_expression = var.warmer_schedule_expression
}

resource "aws_cloudwatch_event_target" "this" {
  count = var.create_eventbridge_scheduled_rule ? 1 : 0

  arn  = aws_lambda_function.this.arn
  rule = aws_cloudwatch_event_rule.this[0].name
}
