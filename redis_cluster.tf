# Create Redis Subnet Group
resource "aws_elasticache_subnet_group" "redis_subnet_group" {
  name       = "my-redis-subnet-group"
  subnet_ids = [
    aws_subnet.private_subnet_1.id,
    aws_subnet.private_subnet_2.id
  ]

  tags = {
    Name = "my-redis-subnet-group"
  }
}

# Create Redis Replication Group for Read Replica
resource "aws_elasticache_replication_group" "redis_replication" {
  replication_group_id = "my-redis-replication-group"
  description = "Redis replication group with primary and read replica"
  node_type = var.redis_instance_type
  replicas_per_node_group = 1
  automatic_failover_enabled = true
  subnet_group_name = aws_elasticache_subnet_group.redis_subnet_group.name
  security_group_ids = [aws_security_group.redis_cluster_sg.id]
  port = 6379
  parameter_group_name = "default.redis7"
  at_rest_encryption_enabled = true
  tags = {
    Name = "my-redis-replication-group"
  }
}

# Add CNAME records for Redis endpoints
resource "aws_route53_record" "primary_redis" {
  zone_id = aws_route53_zone.private_hosted_zone.id
  name = "redis-primary.terraproject.in"
  type = "CNAME"
  ttl = 60
  records = [aws_elasticache_replication_group.redis_replication.primary_endpoint_address]
}

resource "aws_route53_record" "replica_redis" {
  zone_id = aws_route53_zone.private_hosted_zone.id
  name = "redis-replicas.terraproject.in"
  type = "CNAME"
  ttl = 60
  records = [aws_elasticache_replication_group.redis_replication.reader_endpoint_address]
}