resource "aws_security_group" "this" {
  name_prefix = "${var.name}-"
  description = "Allow NeedU V3 EKS nodes to connect to Valkey"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.display_name}-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "eks" {
  security_group_id            = aws_security_group.this.id
  referenced_security_group_id = var.eks_node_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = 6379
  to_port                      = 6379
  description                  = "TLS Valkey access from V3 EKS nodes"
}

resource "aws_elasticache_subnet_group" "this" {
  name       = "${var.name}-subnets"
  subnet_ids = var.subnet_ids
}

resource "aws_elasticache_replication_group" "this" {
  replication_group_id = var.name
  description          = "NeedU V3 Dev Valkey"
  engine               = "valkey"
  engine_version       = var.engine_version
  node_type            = var.node_type
  port                 = 6379

  num_cache_clusters         = 1
  automatic_failover_enabled = false
  multi_az_enabled           = false

  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  transit_encryption_mode    = "required"

  subnet_group_name  = aws_elasticache_subnet_group.this.name
  security_group_ids = [aws_security_group.this.id]

  snapshot_retention_limit = 0
  apply_immediately        = false

  tags = { Name = var.display_name }
}