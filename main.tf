resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  tags = {
    Name = "prefect-ecs"
  }
}

resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "prefect-ecs-public-1"
  }
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "prefect-ecs-public-2"
  }
}

resource "aws_subnet" "public_3" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1c"
  map_public_ip_on_launch = true

  tags = {
    Name = "prefect-ecs-public-3"
  }
}

resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.10.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "prefect-ecs-private-1"
  }
}

resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "prefect-ecs-private-2"
  }
}

resource "aws_subnet" "private_3" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.12.0/24"
  availability_zone = "us-east-1c"

  tags = {
    Name = "prefect-ecs-private-3"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "prefect-ecs"
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_1.id

  tags = {
    Name = "prefect-ecs"
  }
}

resource "aws_eip" "nat" {}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = {
    Name = "prefect-ecs-public"
  }
}

# Public subnet associations
resource "aws_route_table_association" "public_assoc_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_assoc_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_assoc_3" {
  subnet_id      = aws_subnet.public_3.id
  route_table_id = aws_route_table.public.id
}

# Private subnet associations
resource "aws_route_table_association" "private_assoc_1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_assoc_2" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_assoc_3" {
  subnet_id      = aws_subnet.private_3.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = {
    Name = "prefect-ecs-private"
  }
}

resource "aws_ecs_cluster" "prefect" {
  name = var.ecs_cluster_name
    service_connect_defaults {
    namespace = aws_service_discovery_private_dns_namespace.prefect.arn
  }
  tags = {
    Name = "prefect-ecs"
  }
}

resource "aws_service_discovery_private_dns_namespace" "prefect" {
  name        = "default.prefect.local"
  description = "Private DNS namespace for Prefect ECS services"
  vpc         = aws_vpc.main.id

  tags = {
    Name = "default.prefect.local"
  }
}

resource "aws_iam_role" "prefect_task_execution" {
  name = "prefect-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "prefect-task-execution-role"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_execution_policy" {
  role       = aws_iam_role.prefect_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_caller_identity" "current" {}

resource "aws_iam_policy" "secrets_manager_access" {
  name = "prefect-secrets-manager-access"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ],
        Resource = "arn:aws:secretsmanager:us-east-1:${data.aws_caller_identity.current.account_id}:secret:prefect-api-key-*"
      }
    ]
  })
}

resource "aws_iam_policy_attachment" "secrets_manager_policy_attachment" {
  name       = "attach-prefect-secrets"
  roles      = [aws_iam_role.prefect_task_execution.name]
  policy_arn = aws_iam_policy.secrets_manager_access.arn
}

data "aws_secretsmanager_secret_version" "prefect_api_key" {
  secret_id = "prefect-api-key-dev"
}

resource "aws_ecs_task_definition" "prefect_worker" {
  family                   = "dev-worker"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.prefect_task_execution.arn
  task_role_arn            = aws_iam_role.prefect_task_execution.arn

  container_definitions = jsonencode([
    {
      name      = "prefect-worker"
      image     = "prefecthq/prefect:2-latest"
      essential = true
      environment = [
        {
          name  = "PREFECT_API_URL"
          value = var.prefect_account_url
        },
        {
          name  = "PREFECT_WORK_POOL_NAME"
          value = "ecs-work-pool"
        },
        {
          name  = "PREFECT_ACCOUNT_ID"
          value = var.prefect_account_id
        },
        {
          name  = "PREFECT_WORKSPACE_ID"
          value = var.prefect_workspace_id
        }
      ]
      secrets = [
        {
          name      = "PREFECT_API_KEY"
          valueFrom = data.aws_secretsmanager_secret_version.prefect_api_key.arn
        }
      ]
      command = ["prefect", "worker", "start", "--pool", "ecs-work-pool", "--name", "dev-worker"]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/dev-worker"
          awslogs-region        = "us-east-1"
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "prefect_worker" {
  name            = "dev-worker"
  cluster         = aws_ecs_cluster.prefect.id
  task_definition = aws_ecs_task_definition.prefect_worker.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = [
      aws_subnet.private_1.id,
      aws_subnet.private_2.id,
      aws_subnet.private_3.id
    ]
    assign_public_ip = false
    security_groups  = [aws_security_group.worker_sg.id]
  }

  depends_on = [
    aws_ecs_cluster.prefect,
    aws_iam_role.prefect_task_execution
  ]
}

resource "aws_cloudwatch_log_group" "ecs_worker_logs" {
  name              = "/ecs/dev-worker"
  retention_in_days = 7
}

resource "aws_security_group" "worker_sg" {
  name        = "worker-sg"
  description = "Allow internal VPC traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
