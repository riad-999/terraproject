# Variables
variable "react_app_tg_name" {
  default = "react-app-terraproject-tg"
}

variable "node_app_tg_name" {
  default = "node-app-terraproject-tg"
}

variable "ssl_certificate_arn" {
  description = "The ARN of the SSL certificate"
  default = "arn:aws:acm:us-east-1:087380772019:certificate/395b13d5-692e-4bdf-95e7-6ea8d5e58823"
}

variable "public_hosted_zone_id" {
  default = "Z00642803VUQ7QPG2UWCX"
}

# Target Group for React App
resource "aws_lb_target_group" "react_app_tg" {
  name     = var.react_app_tg_name
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.terraproject_vpc.id
  target_type = "ip"

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold    = 2
    unhealthy_threshold  = 2
  }

  tags = {
    Name = var.react_app_tg_name
  }
}

# Target Group for Node.js App
resource "aws_lb_target_group" "node_app_tg" {
  name     = var.node_app_tg_name
  port     = 3000
  protocol = "HTTP"
  vpc_id   = aws_vpc.terraproject_vpc.id
  target_type = "ip"

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold    = 2
    unhealthy_threshold  = 2
  }

  tags = {
    Name = var.node_app_tg_name
  }
}

# Application Load Balancer
resource "aws_lb" "app_alb" {
  name               = "app-terraproject-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.ALB_sg.id]
  subnets            = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]

  enable_deletion_protection = false
  enable_http2               = true

  tags = {
    Name = "app-alb"
  }
}

# HTTPS Listener for React App
resource "aws_lb_listener" "https_listener_react" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.ssl_certificate_arn

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.react_app_tg.arn
  }
}

# HTTP Listener for Node.js App (Port 3000)
resource "aws_lb_listener" "https_listener_node" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = 3000
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.ssl_certificate_arn
  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.node_app_tg.arn
  }
}

# Route 53 CNAME Record for ALB
resource "aws_route53_record" "nodeapp_cname" {
  zone_id = var.public_hosted_zone_id # Replace with your actual hosted zone ID
  name    = "nodeapp.riadprojects.xyz"
  type    = "CNAME"
  ttl     = 300

  records = [aws_lb.app_alb.dns_name]  # ALB DNS name
}