# 기존 V2 Dev Redis 보안 그룹은 V2 Terraform이 소유한다.
# V3는 해당 보안 그룹에 EKS 출발지 규칙만 별도 관리한다.

data "aws_security_group" "dev_redis" {
  id = "sg-067a45fde040402bb"
}

resource "aws_vpc_security_group_ingress_rule" "dev_redis_from_eks" {
  security_group_id            = data.aws_security_group.dev_redis.id
  referenced_security_group_id = data.aws_eks_cluster.valkey.vpc_config[0].cluster_security_group_id

  ip_protocol = "tcp"
  from_port   = 6379
  to_port     = 6379

  description = "Redis access from V3 Dev EKS nodes"
}