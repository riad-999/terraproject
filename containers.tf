variable "ecs_task_exec_role_arn" {
  default = "arn:aws:iam::087380772019:role/ecsTaskExecutionRole"
}

resource "aws_cloudwatch_log_group" "node_app_log_group" {
  name              = "/ecs/node-app-terraproject"
  retention_in_days = 30  # Retain logs for 30 days, adjust as needed

  tags = {
    Name = "node-app-log-group"
    Environment = "production"
  }
}


resource "aws_ecs_task_definition" "node_app_task_def" {
  family                   = "node-app-task-def-terraproject"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "1024"
  memory                   = "3072"
  execution_role_arn       = var.ecs_task_exec_role_arn

  container_definitions = jsonencode([
    {
      name      = "node-app",
      image     = "riadflh/node-app-img",
      essential = true,
      portMappings = [
        {
          containerPort = 3000,
          hostPort      = 3000,
          protocol      = "tcp"
        }
      ],
      environment = [
        {
          name  = "PORT",
          value = "3000"
        },
        {
          name  = "REDIS_REPLICAS_URL",
          value = "redis://redis-replicas.terraproject.in:6379"
        },
        {
          name  = "REDIS_URL",
          value = "redis://redis-primary.terraproject.in:6379"
        }
      ],
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.node_app_log_group.name,
          "awslogs-region"        = var.region,
          "awslogs-stream-prefix" = "ecs",
          "mode"                  = "non-blocking",
          "max-buffer-size"       = "25m"
        }
      }
    }
  ])

  runtime_platform {
    cpu_architecture       = "X86_64"
    operating_system_family = "LINUX"
  }
}


resource "aws_cloudwatch_log_group" "react_app_log_group" {
  name              = "/ecs/react-app-terraproject"
  retention_in_days = 30  # Retain logs for 30 days, adjust as needed

  tags = {
    Name = "react-app-log-group"
    Environment = "production"
  }
}

resource "aws_ecs_task_definition" "react_app_task_def" {
  family                   = "react-app-task-def-terraproject"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "1024"
  memory                   = "2048"
  execution_role_arn       = var.ecs_task_exec_role_arn

  container_definitions = jsonencode([
    {
      name      = "react-app",
      image     = "riadflh/react-app-img:terra-project",
      cpu       = 1024,
      memory    = 2048,
      essential = true,
      portMappings = [
        {
          containerPort = 80,
          hostPort      = 80,
          protocol      = "tcp"
        }
      ],
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.react_app_log_group.name,
          "awslogs-region"        = var.region,
          "awslogs-stream-prefix" = "ecs",
          "mode"                  = "non-blocking",
          "max-buffer-size"       = "25m"
        }
      }
    }
  ])

  runtime_platform {
    cpu_architecture       = "X86_64"
    operating_system_family = "LINUX"
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "my_cluster" {
  name = "my-ecs-cluster"
}

# ECS Service for Node.js App
resource "aws_ecs_service" "node_service" {
  name            = "node-app-service"
  cluster         = aws_ecs_cluster.my_cluster.id     # Reference to the created ECS cluster
  task_definition = aws_ecs_task_definition.node_app_task_def.arn  # Use the task definition for the Node.js app
  desired_count   = 1                                 # Initial number of tasks to run

  launch_type     = "FARGATE"

  load_balancer {
    target_group_arn = aws_lb_target_group.node_app_tg.arn   # ARN of the existing target group
    container_name   = "node-app"                     # Name of the container in the task definition
    container_port   = 3000                           # Port exposed by the container
  }

  network_configuration {
    subnets          = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id] # Public subnets
    security_groups  = [aws_security_group.node_app_sg.id]                            # Security group for the service
    assign_public_ip = false
  }

  deployment_minimum_healthy_percent = 50  # Minimum healthy task percent during deployment
  deployment_maximum_percent         = 200 # Maximum task percent during deployment

  depends_on = [
    aws_lb_listener.https_listener_node   # Listener for the ALB on port 3000
  ]

  tags = {
    Name = "node-app-service"
  }
}

# Auto-scaling target for ECS Service
resource "aws_appautoscaling_target" "node_service_autoscaling" {
  max_capacity       = 2                          # Maximum number of tasks
  min_capacity       = 1                            # Minimum number of tasks
  resource_id        = "service/${aws_ecs_cluster.my_cluster.name}/${aws_ecs_service.node_service.name}"  # ECS service resource ID
  scalable_dimension = "ecs:service:DesiredCount"   # ECS scalable dimension for service desired count
  service_namespace  = "ecs"                        # AWS ECS namespace
}

# Auto-scaling policy based on CPU usage
resource "aws_appautoscaling_policy" "cpu_scaling_policy_node" {
  name               = "cpu-scaling-policy"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.node_service_autoscaling.resource_id
  scalable_dimension = aws_appautoscaling_target.node_service_autoscaling.scalable_dimension
  service_namespace  = aws_appautoscaling_target.node_service_autoscaling.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 75.0  # Target CPU utilization percentage
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    scale_in_cooldown  = 300  # Time to wait before scaling in
    scale_out_cooldown = 300  # Time to wait before scaling out
  }
}

# -------------------------------------------



# ECS Service for Node.js App
resource "aws_ecs_service" "react_service" {
  name            = "react-app-service"
  cluster         = aws_ecs_cluster.my_cluster.id     # Reference to the created ECS cluster
  task_definition = aws_ecs_task_definition.react_app_task_def.arn  # Use the task definition for the Node.js app
  desired_count   = 1                                 # Initial number of tasks to run

  launch_type     = "FARGATE"

  load_balancer {
    target_group_arn = aws_lb_target_group.react_app_tg.arn # ARN of the existing target group
    container_name   = "react-app"                     # Name of the container in the task definition
    container_port   = 80                          # Port exposed by the container
  }

  network_configuration {
    subnets          = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id] # Public subnets
    security_groups  = [aws_security_group.react_app_sg.id]                            # Security group for the service
    assign_public_ip = false
  }

  deployment_minimum_healthy_percent = 50  # Minimum healthy task percent during deployment
  deployment_maximum_percent         = 200 # Maximum task percent during deployment

  depends_on = [
    aws_lb_listener.https_listener_react   # Listener for the ALB on port 3000
  ]

  tags = {
    Name = "react-app-service"
  }
}

# Auto-scaling target for ECS Service
resource "aws_appautoscaling_target" "react_service_autoscaling" {
  max_capacity       = 2                          # Maximum number of tasks
  min_capacity       = 1                            # Minimum number of tasks
  resource_id        = "service/${aws_ecs_cluster.my_cluster.name}/${aws_ecs_service.react_service.name}"  # ECS service resource ID
  scalable_dimension = "ecs:service:DesiredCount"   # ECS scalable dimension for service desired count
  service_namespace  = "ecs"                        # AWS ECS namespace
}

# Auto-scaling policy based on CPU usage
resource "aws_appautoscaling_policy" "cpu_scaling_policy_react" {
  name               = "cpu-scaling-policy"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.react_service_autoscaling.resource_id
  scalable_dimension = aws_appautoscaling_target.react_service_autoscaling.scalable_dimension
  service_namespace  = aws_appautoscaling_target.react_service_autoscaling.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 75.0  # Target CPU utilization percentage
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    scale_in_cooldown  = 300  # Time to wait before scaling in
    scale_out_cooldown = 300  # Time to wait before scaling out
  }
}