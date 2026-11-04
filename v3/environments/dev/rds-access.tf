# V2 Dev RDS 인스턴스의 보안 그룹은 V2 Terraform이 소유한다.
# V3는 해당 보안 그룹에 EKS 출발지 규칙 두 개만 별도 관리한다.
data "aws_security_group" "dev_mysql" {
  vpc_id = module.network.vpc_id

  filter {
    name   = "group-name"
    values = ["needu-dev-mysql-*"]
  }
}

data "aws_security_group" "dev_postgres" {
  vpc_id = module.network.vpc_id

  filter {
    name   = "group-name"
    values = ["needu-dev-postgres-*"]
  }
}

resource "aws_vpc_security_group_ingress_rule" "dev_mysql_from_eks" {
  security_group_id            = data.aws_security_group.dev_mysql.id
  referenced_security_group_id = data.aws_eks_cluster.valkey.vpc_config[0].cluster_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = 3306
  to_port                      = 3306
  description                  = "MySQL access from V3 Dev EKS nodes"
}

resource "aws_vpc_security_group_ingress_rule" "dev_postgres_from_eks" {
  security_group_id            = data.aws_security_group.dev_postgres.id
  referenced_security_group_id = data.aws_eks_cluster.valkey.vpc_config[0].cluster_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  description                  = "PostgreSQL access from V3 Dev EKS nodes"
}
