aws_region = "ap-northeast-2"
name       = "needu-v3-prod"

vpc_id                     = "vpc-0f2478c01e376b1b6"
availability_zones         = ["ap-northeast-2a", "ap-northeast-2b", "ap-northeast-2c"]
existing_public_subnet_ids = ["subnet-05ebd035963ad66d9", "subnet-0258a53c491aa8964"]
new_public_subnet_cidr     = "10.1.18.0/24"
private_subnet_cidrs       = ["10.1.80.0/24", "10.1.81.0/24", "10.1.82.0/24"]
internet_gateway_id        = "igw-016a1e5edf942de18"
cluster_version            = "1.36"
node_instance_types        = ["t3.large"]
system_max_per_az          = 2
app_max_per_az             = 2
eks_public_access_cidrs    = ["118.176.114.97/32", "211.244.225.224/32"]
eks_cluster_admin_role_arn = "arn:aws:iam::919551759796:role/aws-reserved/sso.amazonaws.com/ap-northeast-2/AWSReservedSSO_NeedU-Terraform-Bootstrap-Admin_39de7a047c7b6ba8"
eso_secret_kms_key_arns    = []
