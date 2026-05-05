# ═══════════════════ ECR + ECS FARGATE ═══════════════════

resource "aws_ecr_repository" "main" {
  name                 = "${var.project}-summarisation"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.main.arn
  }

  tags = { Name = "${var.project}-summarisation-ecr" }
}

resource "aws_ecs_cluster" "main" {
  name = "${var.project}-cluster-${var.env}"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = { Name = "${var.project}-cluster" }
}

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.project}-summarisation-${var.env}"
  retention_in_days = 30
  tags              = { Name = "${var.project}-ecs-logs" }
}

resource "aws_ecs_task_definition" "main" {
  family                   = "${var.project}-summarisation-${var.env}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "1024"
  memory                   = "2048"
  execution_role_arn       = aws_iam_role.ecs_exec.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name      = "summarisation"
    image     = "${aws_ecr_repository.main.repository_url}:v1"
    essential = true
    environment = [
      { name = "ENRICHED_BUCKET", value = aws_s3_bucket.enriched.id },
      { name = "MODEL_ID", value = "anthropic.claude-3-5-sonnet-20241022-v2:0" },
      { name = "AWS_REGION", value = var.region },
      { name = "ENVIRONMENT", value = var.env }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
        "awslogs-region"        = var.region
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])

  tags = { Name = "${var.project}-summarisation-task" }
}

resource "aws_ecs_service" "main" {
  name            = "${var.project}-summarisation-${var.env}"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.main.arn
  desired_count   = 0
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  tags = { Name = "${var.project}-summarisation-svc" }
}
