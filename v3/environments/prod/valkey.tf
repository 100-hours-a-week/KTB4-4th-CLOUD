# Production EKS cluster security group (same lookup pattern as V3 Dev).
# Verify this SG is attached to the application nodes/pods before apply.
data "aws_eks_cluster" "valkey" {
  name = module.eks.cluster_name
}

locals {
  # Two private subnets in different AZs for primary + replica.
  valkey_subnet_ids = [
    aws_subnet.private[var.availability_zones[0]].id,
    aws_subnet.private[var.availability_zones[1]].id,
  ]
}

module "valkey" {
  source = "../../modules/valkey"

  name         = "${var.name}-valkey"
  display_name = "${var.name}-valkey-streams"
  description  = "NeedU V3 Production Valkey Streams"

  vpc_id                     = var.vpc_id
  subnet_ids                 = local.valkey_subnet_ids
  eks_node_security_group_id = data.aws_eks_cluster.valkey.vpc_config[0].cluster_security_group_id

  num_cache_clusters         = 2
  automatic_failover_enabled = true
  multi_az_enabled           = true
  snapshot_retention_limit   = 7
}

module "valkey_cache" {
  source = "../../modules/valkey"

  name         = "${var.name}-valkey-a"
  display_name = "${var.name}-valkey-cache"
  description  = "NeedU V3 Production Valkey Cache"

  vpc_id                     = var.vpc_id
  subnet_ids                 = local.valkey_subnet_ids
  eks_node_security_group_id = data.aws_eks_cluster.valkey.vpc_config[0].cluster_security_group_id

  num_cache_clusters         = 2
  automatic_failover_enabled = true
  multi_az_enabled           = true
  snapshot_retention_limit   = 7
}
