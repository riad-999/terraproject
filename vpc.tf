# VPC creation
resource "aws_vpc" "terraproject_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = "terraproject_vpc"
  }
}

# Public Subnets
resource "aws_subnet" "public_subnet_1" {
  vpc_id     = aws_vpc.terraproject_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = var.zone1
  map_public_ip_on_launch = true
  tags = {
    Name = "public_subnet_1"
  }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id     = aws_vpc.terraproject_vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = var.zone2
  map_public_ip_on_launch = true
  tags = {
    Name = "public_subnet_2"
  }
}

# Private Subnets
resource "aws_subnet" "private_subnet_1" {
  vpc_id     = aws_vpc.terraproject_vpc.id
  cidr_block = "10.0.3.0/24"
  availability_zone = var.zone1
  tags = {
    Name = "private_subnet_1"
  }
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id     = aws_vpc.terraproject_vpc.id
  cidr_block = "10.0.4.0/24"
  availability_zone = var.zone2
  tags = {
    Name = "private_subnet_2"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "terraproject_igw" {
  vpc_id = aws_vpc.terraproject_vpc.id
  tags = {
    Name = "terraproject_igw"
  }
}

# NAT Gateway (requires an Elastic IP)
resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "my_nat_gateway" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet_1.id
  tags = {
    Name = "my_nat_gateway"
  }
}

# Route Table for Public Subnets
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.terraproject_vpc.id
  tags = {
    Name = "public_route_table"
  }
}

# Route for Internet Access in Public Subnets
resource "aws_route" "public_route" {
  route_table_id         = aws_route_table.public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.terraproject_igw.id
}

# Associate Public Route Table with Public Subnets
resource "aws_route_table_association" "public_route_table_assoc_1" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "public_route_table_assoc_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_route_table.id
}

# Route Table for Private Subnets
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.terraproject_vpc.id
  tags = {
    Name = "private_route_table"
  }
}

# Route for NAT Gateway in Private Subnets
resource "aws_route" "private_route" {
  route_table_id         = aws_route_table.private_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.my_nat_gateway.id
}

# Associate Private Route Table with Private Subnets
resource "aws_route_table_association" "private_route_table_assoc_1" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_route_table.id
}

resource "aws_route_table_association" "private_route_table_assoc_2" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private_route_table.id
}

# Route 53 Private Hosted Zone
resource "aws_route53_zone" "private_hosted_zone" {
  name = "terraproject.in" # Replace with your domain name
  vpc {
    vpc_id = aws_vpc.terraproject_vpc.id
  }
  lifecycle {
    prevent_destroy = true
  }
  comment = "Private hosted zone for example.com within VPC"
}

# Security Group for ALB (Application Load Balancer)
resource "aws_security_group" "ALB_sg" {
  vpc_id = aws_vpc.terraproject_vpc.id
  name   = "ALB_sg"

  # Allow HTTPS access from anywhere (0.0.0.0/0) on port 443
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow access on port 3000 from anywhere (0.0.0.0/0)
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ALB_sg"
  }
}

# Security Group for Node.js application
resource "aws_security_group" "node_app_sg" {
  vpc_id = aws_vpc.terraproject_vpc.id
  name   = "node_app_sg"

  # Allow HTTP access from the ALB security group (ALB_sg) on port 3000
  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.ALB_sg.id]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "node_app_sg"
  }
}

# Security Group for React Application
resource "aws_security_group" "react_app_sg" {
  vpc_id = aws_vpc.terraproject_vpc.id
  name   = "react_app_sg"

  # Allow HTTP access from the ALB security group (ALB_sg) on port 80
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.ALB_sg.id]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "react_app_sg"
  }
}

# Security Group for Redis Cluster
resource "aws_security_group" "redis_cluster_sg" {
  vpc_id = aws_vpc.terraproject_vpc.id
  name   = "redis_cluster_sg"

  # Allow Redis access from node_app_sg on port 6379 (default Redis port)
  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.node_app_sg.id]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "redis_cluster_sg"
  }
}