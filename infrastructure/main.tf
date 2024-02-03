resource "aws_ecr_repository" "ecs_repo" {
  name                 = "dev-ecr"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}


resource "aws_ecs_cluster" "ecs_cluster" {
  name = "petclinic-cluster"
}

resource "aws_iam_role" "ecsiamrole" {
  name = "ecsTaskExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {

        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      },
    ]
  })
}
resource "aws_cloudwatch_log_group" "ecs_log_group" {
  name              = "/ecs/dev-ecr"
  retention_in_days = 30 # Configure conforme necessário
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy_attachment" {
  role       = aws_iam_role.ecsiamrole.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_task_definition" "petclinic_task" {
  family                   = "petclinic"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecsiamrole.arn
  container_definitions = jsonencode([
    {
      name      = "petclinic"
      image     = "${aws_ecr_repository.ecs_repo.repository_url}:latest"
      cpu       = 256
      memory    = 512
      essential = true
      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
        },
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs_log_group.name
          awslogs-region        = "us-east-1"
          awslogs-stream-prefix = "ecs"
        }
      }
    },
  ])
}

resource "aws_ecs_service" "petclinic_service" {
  name            = "petclinic-service"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.petclinic_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.subnet.id, aws_subnet.subnet2.id]
    assign_public_ip = true
    security_groups  = [aws_security_group.security_group.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.petclinic_tg.arn
    container_name   = "petclinic"
    container_port   = 8080
  }
  depends_on = [
    aws_lb_listener.front_end,
  ]
}

resource "aws_appautoscaling_target" "ecs_target" {
  max_capacity       = 10
  min_capacity       = 1
  resource_id        = "service/petclinic-cluster/petclinic-service"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "cpu_scale_out" {
  name               = "cpu_scale_out"
  policy_type        = "StepScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Average"

    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment          = 1
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "high_cpu_utilization" {
  alarm_name          = "high_cpu_utilization"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "This metric monitors ecs cpu utilization"
  datapoints_to_alarm = 2
  dimensions = {
    ClusterName = "petclinic-cluster"
    ServiceName = "petclinic-service"
  }
  actions_enabled = true
  alarm_actions   = [aws_appautoscaling_policy.cpu_scale_out.arn]
  ok_actions      = [aws_appautoscaling_policy.cpu_scale_out.arn]
}

resource "aws_appautoscaling_policy" "cpu_scale_in" {
  name               = "cpu_scale_in"
  policy_type        = "StepScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Average"

    step_adjustment {
      metric_interval_upper_bound = 0
      scaling_adjustment          = -1
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "low_cpu_utilization" {
  alarm_name          = "low_cpu_utilization"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = 40
  alarm_description   = "This metric monitors ecs cpu utilization for scaling in"
  datapoints_to_alarm = 2
  dimensions = {
    ClusterName = "petclinic-cluster"
    ServiceName = "petclinic-service"
  }
  actions_enabled = true
  alarm_actions   = [aws_appautoscaling_policy.cpu_scale_in.arn]
}

resource "aws_lb" "petclinic-alb" {
  name               = "petclinic-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.security_group.id]
  subnets            = [aws_subnet.subnet.id, aws_subnet.subnet2.id]

  enable_deletion_protection = false
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.petclinic-alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.petclinic_tg.arn
  }

}

resource "aws_lb_target_group" "petclinic_tg" {
  name        = "petclinic-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = data.terraform_remote_state.vpc.outputs.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    path                = "/"
    protocol            = "HTTP"
    interval            = 30
    matcher             = "200"
  }
}