# ═══════════════════ SNS + CLOUDWATCH ALARMS + DASHBOARD ═══════════════════

resource "aws_sns_topic" "alerts" {
  name              = "${var.project}-alerts-${var.env}"
  kms_master_key_id = aws_kms_key.main.id
  tags              = { Name = "${var.project}-alerts" }
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = "alerts@mistavinya.com"
}

resource "aws_sns_topic_subscription" "slack" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.slack_notifier.arn
}

resource "aws_lambda_permission" "sns_slack" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.slack_notifier.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.alerts.arn
}

# Alarms
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  for_each = toset([
    aws_lambda_function.shopify.function_name,
    aws_lambda_function.amazon.function_name,
    aws_lambda_function.flipkart.function_name
  ])

  alarm_name          = "${var.project}-${each.value}-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 2
  dimensions          = { FunctionName = each.value }
  alarm_actions       = [aws_sns_topic.alerts.arn]
  tags                = { Name = "${var.project}-lambda-alarm" }
}

resource "aws_cloudwatch_metric_alarm" "sfn_failures" {
  alarm_name          = "${var.project}-sfn-failures-${var.env}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ExecutionsFailed"
  namespace           = "AWS/States"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  dimensions          = { StateMachineArn = aws_sfn_state_machine.pipeline.arn }
  alarm_actions       = [aws_sns_topic.alerts.arn]
  tags                = { Name = "${var.project}-sfn-alarm" }
}

resource "aws_cloudwatch_metric_alarm" "ecs_failures" {
  alarm_name          = "${var.project}-ecs-failures-${var.env}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "RunningTaskCount"
  namespace           = "ECS/ContainerInsights"
  period              = 300
  statistic           = "Average"
  threshold           = 0
  treat_missing_data  = "notBreaching"
  dimensions          = { ClusterName = aws_ecs_cluster.main.name, ServiceName = aws_ecs_service.main.name }
  alarm_actions       = [aws_sns_topic.alerts.arn]
  tags                = { Name = "${var.project}-ecs-alarm" }
}

# Dashboard
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project}-pipeline-health-${var.env}"
  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric", x = 0, y = 0, width = 12, height = 6
        properties = {
          title   = "Lambda Invocations"
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.shopify.function_name],
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.amazon.function_name],
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.flipkart.function_name]
          ]
          period = 300
          region = var.region
        }
      },
      {
        type = "metric", x = 12, y = 0, width = 12, height = 6
        properties = {
          title   = "Step Functions"
          metrics = [
            ["AWS/States", "ExecutionsSucceeded", "StateMachineArn", aws_sfn_state_machine.pipeline.arn],
            ["AWS/States", "ExecutionsFailed", "StateMachineArn", aws_sfn_state_machine.pipeline.arn]
          ]
          period = 300
          region = var.region
        }
      },
      {
        type = "metric", x = 0, y = 6, width = 12, height = 6
        properties = {
          title   = "Lambda Errors"
          metrics = [
            ["AWS/Lambda", "Errors", "FunctionName", aws_lambda_function.shopify.function_name],
            ["AWS/Lambda", "Errors", "FunctionName", aws_lambda_function.classification.function_name],
            ["AWS/Lambda", "Errors", "FunctionName", aws_lambda_function.pii_redaction.function_name]
          ]
          period = 300
          region = var.region
        }
      },
      {
        type = "metric", x = 12, y = 6, width = 12, height = 6
        properties = {
          title   = "ECS Fargate"
          metrics = [
            ["ECS/ContainerInsights", "CpuUtilized", "ClusterName", aws_ecs_cluster.main.name],
            ["ECS/ContainerInsights", "MemoryUtilized", "ClusterName", aws_ecs_cluster.main.name]
          ]
          period = 300
          region = var.region
        }
      }
    ]
  })
}
