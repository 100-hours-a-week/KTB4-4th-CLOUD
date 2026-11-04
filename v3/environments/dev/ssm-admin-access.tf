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

resource "aws_eks_access_entry" "ssm_admin" {
  cluster_name  = module.eks.cluster_name
  principal_arn = "arn:aws:iam::919551759796:role/needu-dev-ssm-bastion"
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "ssm_admin" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_eks_access_entry.ssm_admin.principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}
