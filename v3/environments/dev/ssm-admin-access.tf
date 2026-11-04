data "aws_eks_cluster" "dev_admin_access" {
  name = module.eks.cluster_name
}

variable "ssm_admin_security_group_id" {
  description = "Existing needu-dev-ssm-bastion security group ID"
  type        = string
}

resource "aws_vpc_security_group_ingress_rule" "eks_api_from_ssm_admin" {
  security_group_id            = data.aws_eks_cluster.dev_admin_access.vpc_config[0].cluster_security_group_id
  referenced_security_group_id = var.ssm_admin_security_group_id
  description                  = "Allow Dev SSM admin host to reach the private EKS API"
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
}
