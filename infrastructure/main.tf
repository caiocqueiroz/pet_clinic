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
    subnets          = [aws_subnet.subnet, aws_subnet.subnet2]
    assign_public_ip = true
    security_groups  = [aws_security_group.security_group.id]
  }
}
