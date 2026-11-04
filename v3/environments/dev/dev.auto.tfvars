aws_region           = "ap-northeast-2"
name                 = "needu-v3-dev"
vpc_id               = "vpc-0f2478c01e376b1b6"
availability_zones   = ["ap-northeast-2a", "ap-northeast-2c"]
public_subnet_ids    = ["subnet-0d83afd6ba8e27647", "subnet-0028c486a1b1f8077"]
private_subnet_cidrs = ["10.1.64.0/24", "10.1.65.0/24"]
cluster_version      = "1.33"
node_instance_types  = ["t3.large"]
system_max_per_az    = 2
app_max_per_az       = 2

eks_public_access_cidrs     = ["211.244.225.224/32"]
ssm_admin_security_group_id = "sg-034208f09ce526099"

eks_cluster_admin_role_arn = "arn:aws:iam::919551759796:role/aws-reserved/sso.amazonaws.com/ap-northeast-2/AWSReservedSSO_NeedU-Terraform-Bootstrap-Admin_39de7a047c7b6ba8"
