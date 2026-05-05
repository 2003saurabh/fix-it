# ═══════════════════ EVENTBRIDGE + STEP FUNCTIONS ═══════════════════

resource "aws_cloudwatch_event_rule" "shopify" {
  name          = "${var.project}-shopify-webhook-${var.env}"
  description   = "Route Shopify review webhooks"
  event_pattern = jsonencode({ source = ["shopify.reviews"], "detail-type" = ["Review Created"] })
}

resource "aws_cloudwatch_event_target" "shopify" {
  rule      = aws_cloudwatch_event_rule.shopify.name
  target_id = "shopify"
  arn       = aws_lambda_function.shopify.arn
}

resource "aws_lambda_permission" "eb_shopify" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.shopify.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.shopify.arn
}

resource "aws_cloudwatch_event_rule" "amazon" {
  name                = "${var.project}-amazon-poll-${var.env}"
  schedule_expression = "rate(30 minutes)"
}

resource "aws_cloudwatch_event_target" "amazon" {
  rule      = aws_cloudwatch_event_rule.amazon.name
  target_id = "amazon"
  arn       = aws_lambda_function.amazon.arn
}

resource "aws_lambda_permission" "eb_amazon" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.amazon.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.amazon.arn
}

resource "aws_cloudwatch_event_rule" "flipkart" {
  name                = "${var.project}-flipkart-poll-${var.env}"
  schedule_expression = "rate(30 minutes)"
}

resource "aws_cloudwatch_event_target" "flipkart" {
  rule      = aws_cloudwatch_event_rule.flipkart.name
  target_id = "flipkart"
  arn       = aws_lambda_function.flipkart.arn
}

resource "aws_lambda_permission" "eb_flipkart" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.flipkart.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.flipkart.arn
}

# Step Functions
resource "aws_iam_role_policy" "sfn" {
  name = "policy"
  role = aws_iam_role.sfn.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Allow", Action = "lambda:InvokeFunction", Resource = [aws_lambda_function.pii_redaction.arn, aws_lambda_function.classification.arn] },
    { Effect = "Allow", Action = "sqs:SendMessage", Resource = aws_sqs_queue.dlq.arn }
  ] })
}

resource "aws_sfn_state_machine" "pipeline" {
  name     = "${var.project}-enrichment-pipeline-${var.env}"
  role_arn = aws_iam_role.sfn.arn

  definition = jsonencode({
    Comment = "${var.project} Enrichment Pipeline"
    StartAt = "ProcessBatch"
    States = {
      ProcessBatch = {
        Type           = "Map"
        ItemsPath      = "$.reviews"
        MaxConcurrency = 10
        Iterator = {
          StartAt = "PIIRedaction"
          States = {
            PIIRedaction = {
              Type     = "Task"
              Resource = "arn:aws:states:::lambda:invoke"
              Parameters = {
                FunctionName = aws_lambda_function.pii_redaction.arn
                "Payload.$"  = "$"
              }
              ResultPath = "$.redacted"
              Next       = "Classification"
              Retry = [{ ErrorEquals = ["States.TaskFailed"], IntervalSeconds = 5, MaxAttempts = 3, BackoffRate = 2.0 }]
              Catch = [{ ErrorEquals = ["States.ALL"], Next = "SendToDLQ" }]
            }
            Classification = {
              Type     = "Task"
              Resource = "arn:aws:states:::lambda:invoke"
              Parameters = {
                FunctionName = aws_lambda_function.classification.arn
                "Payload.$"  = "$.redacted.Payload"
              }
              ResultPath = "$.classified"
              End        = true
              Retry = [{ ErrorEquals = ["States.TaskFailed"], IntervalSeconds = 10, MaxAttempts = 3, BackoffRate = 2.0 }]
              Catch = [{ ErrorEquals = ["States.ALL"], Next = "SendToDLQ" }]
            }
            SendToDLQ = {
              Type     = "Task"
              Resource = "arn:aws:states:::sqs:sendMessage"
              Parameters = {
                QueueUrl       = aws_sqs_queue.dlq.url
                "MessageBody.$" = "$"
              }
              End = true
            }
          }
        }
        Next = "Done"
      }
      Done = { Type = "Succeed" }
    }
  })

  tags = { Name = "${var.project}-enrichment-pipeline" }
}

# EventBridge Scheduler — daily summarisation
resource "aws_iam_role" "scheduler" {
  name               = "${var.project}-scheduler-${var.env}"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Service = "scheduler.amazonaws.com" }, Action = "sts:AssumeRole" }] })
}

resource "aws_iam_role_policy" "scheduler" {
  name = "policy"
  role = aws_iam_role.scheduler.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Allow", Action = "ecs:RunTask", Resource = aws_ecs_task_definition.main.arn },
    { Effect = "Allow", Action = "iam:PassRole", Resource = [aws_iam_role.ecs_exec.arn, aws_iam_role.ecs_task.arn] }
  ] })
}

resource "aws_scheduler_schedule" "summarise" {
  name       = "${var.project}-summarise-daily-${var.env}"
  group_name = "default"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression = "rate(24 hours)"

  target {
    arn      = aws_ecs_cluster.main.arn
    role_arn = aws_iam_role.scheduler.arn

    ecs_parameters {
      task_definition_arn = aws_ecs_task_definition.main.arn
      launch_type         = "FARGATE"

      network_configuration {
        subnets          = aws_subnet.private[*].id
        security_groups  = [aws_security_group.ecs.id]
        assign_public_ip = false
      }
    }
  }
}
