
module "network" {
  source               = "../../modules/network"
  name                 = var.name
  vpc_id               = var.vpc_id
  availability_zones   = var.availability_zones
  public_subnet_ids    = var.public_subnet_ids
  private_subnet_cidrs = var.private_subnet_cidrs
}

module "eks" {
  source                 = "../../modules/eks"
  name                   = var.name
  cluster_version        = var.cluster_version
  vpc_id                 = module.network.vpc_id
  private_subnet_ids     = module.network.private_subnet_ids
  node_instance_types    = var.node_instance_types
  availability_zones     = var.availability_zones
  system_max_per_az      = var.system_max_per_az
  app_max_per_az         = var.app_max_per_az
  public_access_cidrs    = var.eks_public_access_cidrs
  cluster_admin_role_arn = var.eks_cluster_admin_role_arn
}

# EKS Cluster Security Group 조회
data "aws_eks_cluster" "valkey" {
  name = module.eks.cluster_name
}

# Valkey Streams - AI 작업 큐 / Consumer Group / AI Lock
module "valkey" {
  source = "../../modules/valkey"

  name                       = "${var.name}-valkey"
  vpc_id                     = module.network.vpc_id
  subnet_ids                 = var.valkey_subnet_ids
  eks_node_security_group_id = data.aws_eks_cluster.valkey.vpc_config[0].cluster_security_group_id
}

# Valkey Cache - OAuth / Rate Limit / Cooldown / Pub/Sub
module "valkey_cache" {
  source = "../../modules/valkey"

  name                       = "${var.name}-valkey-cache"
  vpc_id                     = module.network.vpc_id
  subnet_ids                 = var.valkey_subnet_ids
  eks_node_security_group_id = data.aws_eks_cluster.valkey.vpc_config[0].cluster_security_group_id
}
