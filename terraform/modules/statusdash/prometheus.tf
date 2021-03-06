resource "aws_prometheus_workspace" "statusdash" {
  alias = "statusdash-nowcasting"
}

resource "aws_ecs_service" "monitoring" {
  name            = "monitoring"
  cluster         = var.ecs-cluster.id
  launch_type     = "FARGATE"

  task_definition = aws_ecs_task_definition.statusdash-task-definition.arn
  desired_count   = 1

  force_new_deployment = true

  network_configuration {

      subnets          = var.subnet_ids
      assign_public_ip = true

    }
}

resource "aws_ecs_task_definition" "statusdash-task-definition" {
  family = "statusdash"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"

  cpu    = 256
  memory = 512

  task_role_arn      = aws_iam_role.statusdash-iam-role.arn
  execution_role_arn = aws_iam_role.ecs_task_execution_role-statusdash.arn
  container_definitions = jsonencode([
    {
      name      = "prometheus"
      image     = "openclimatefix/nowcasting_status:v0.1.0"
      essential = true

      logConfiguration : {
        "logDriver" : "awslogs",
        "options" : {
          "awslogs-group" : var.log-group-name,
          "awslogs-region" : var.region,
          "awslogs-stream-prefix" : "streaming"
        }
      }
    }
  ])
}

# +++++++++++++++++++++++++++
# IAM
# +++++++++++++++++++++++++++
resource "aws_iam_role" "ecs_task_execution_role-statusdash" {
  name = "ecs-statusdash-execution-role"

    assume_role_policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Action": "sts:AssumeRole",
     "Principal": {
       "Service": "ecs-tasks.amazonaws.com"
     },
     "Effect": "Allow",
     "Sid": ""
   }
 ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ecs-task-execution-role-policy-attachment" {
  role       = aws_iam_role.ecs_task_execution_role-statusdash.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# IAM Role for Task
resource "aws_iam_role" "statusdash-iam-role" {
  name               = "statusdash-iam-role"
  path               = "/statusdash/"
  assume_role_policy = data.aws_iam_policy_document.statusdash-assume-role-policy.json
}

resource "aws_iam_policy" "write_to_prometheus" {
  name        = "write-to-prometheus"
  description = "Gives write access to nowcasting prometheus instance."

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "aps:RemoteWrite",
        "aps:GetSeries",
        "aps:GetLabels",
        "aps:GetMetricMetadata"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "test-attach" {
  role       = aws_iam_role.statusdash-iam-role.name
  policy_arn = aws_iam_policy.write_to_prometheus.arn
}

data "aws_iam_policy_document" "statusdash-assume-role-policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_cloudwatch_log_group" "statusdash" {
  name = var.log-group-name

  retention_in_days = 7

  tags = {
    Environment = var.environment
    Application = "nowcasting"
  }
}
