# Existing V2 Production Redis Security Group
data "aws_security_group" "v2_prod_redis" {
  id = "sg-0b8e2bb6146059c1a"
}

# Allow V3 Production EKS to access shared Valkey A
resource "aws_vpc_security_group_ingress_rule" "v2_redis_from_v3_eks" {
  security_group_id = data.aws_security_group.v2_prod_redis.id

  referenced_security_group_id = data.aws_eks_cluster.valkey.vpc_config[0].cluster_security_group_id

  ip_protocol = "tcp"
  from_port   = 6379
  to_port     = 6379

  description = "Allow V3 Production EKS to access shared Valkey A"
}