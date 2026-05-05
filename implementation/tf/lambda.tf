# ═══════════════════ LAMBDA FUNCTIONS ═══════════════════

data "archive_file" "dummy" {
  type        = "zip"
  output_path = "${path.module}/dummy.zip"
  source {
    content  = "def lambda_handler(event, context): return {'statusCode': 200}"
    filename = "handler.py"
  }
}

resource "aws_lambda_function" "shopify" {
  function_name    = "${var.project}-shopify-ingestion-${var.env}"
  role             = aws_iam_role.lambda.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  timeout          = 30
  memory_size      = 256
  filename         = data.archive_file.dummy.output_path
  source_code_hash = data.archive_file.dummy.output_base64sha256

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      RAW_BUCKET  = aws_s3_bucket.raw.id
      MARKETPLACE = "shopify"
      ENVIRONMENT = var.env
    }
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.dlq.arn
  }

  tags = { Name = "${var.project}-shopify-ingestion" }
}

resource "aws_lambda_function" "amazon" {
  function_name    = "${var.project}-amazon-polling-${var.env}"
  role             = aws_iam_role.lambda.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  timeout          = 120
  memory_size      = 256
  filename         = data.archive_file.dummy.output_path
  source_code_hash = data.archive_file.dummy.output_base64sha256

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      RAW_BUCKET  = aws_s3_bucket.raw.id
      MARKETPLACE = "amazon"
      ENVIRONMENT = var.env
    }
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.dlq.arn
  }

  tags = { Name = "${var.project}-amazon-polling" }
}

resource "aws_lambda_function" "flipkart" {
  function_name    = "${var.project}-flipkart-polling-${var.env}"
  role             = aws_iam_role.lambda.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  timeout          = 120
  memory_size      = 256
  filename         = data.archive_file.dummy.output_path
  source_code_hash = data.archive_file.dummy.output_base64sha256

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      RAW_BUCKET  = aws_s3_bucket.raw.id
      MARKETPLACE = "flipkart"
      ENVIRONMENT = var.env
    }
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.dlq.arn
  }

  tags = { Name = "${var.project}-flipkart-polling" }
}

resource "aws_lambda_function" "pii_redaction" {
  function_name    = "${var.project}-pii-redaction-${var.env}"
  role             = aws_iam_role.lambda.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  timeout          = 60
  memory_size      = 512
  filename         = data.archive_file.dummy.output_path
  source_code_hash = data.archive_file.dummy.output_base64sha256

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      ENRICHED_BUCKET = aws_s3_bucket.enriched.id
      ENVIRONMENT     = var.env
    }
  }

  tags = { Name = "${var.project}-pii-redaction" }
}

resource "aws_lambda_function" "classification" {
  function_name    = "${var.project}-classification-${var.env}"
  role             = aws_iam_role.lambda.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  timeout          = 120
  memory_size      = 512
  filename         = data.archive_file.dummy.output_path
  source_code_hash = data.archive_file.dummy.output_base64sha256

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      ENRICHED_BUCKET = aws_s3_bucket.enriched.id
      MODEL_ID        = "anthropic.claude-3-haiku-20240307-v1:0"
      ENVIRONMENT     = var.env
    }
  }

  tags = { Name = "${var.project}-classification" }
}

resource "aws_lambda_function" "slack_notifier" {
  function_name    = "${var.project}-slack-notifier-${var.env}"
  role             = aws_iam_role.lambda.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  timeout          = 10
  memory_size      = 128
  filename         = data.archive_file.dummy.output_path
  source_code_hash = data.archive_file.dummy.output_base64sha256

  environment {
    variables = {
      SLACK_WEBHOOK_URL = "https://hooks.slack.com/placeholder"
    }
  }

  tags = { Name = "${var.project}-slack-notifier" }
}
