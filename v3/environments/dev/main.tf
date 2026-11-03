module "network" {
  source               = "../../modules/network"
  name                 = var.name
  vpc_id               = var.vpc_id
  availability_zones   = var.availability_zones
  public_subnet_ids    = var.public_subnet_ids
  private_subnet_cidrs = var.private_subnet_cidrs
}
module "eks" {
  source              = "../../modules/eks"
  name                = var.name
  cluster_version     = var.cluster_version
  vpc_id              = module.network.vpc_id
  private_subnet_ids  = module.network.private_subnet_ids
  node_instance_types = var.node_instance_types
  system_desired      = var.system_desired
  app_desired         = var.app_desired
}
