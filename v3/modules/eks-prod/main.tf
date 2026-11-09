
data "aws_iam_policy_document" "eks_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster" {
  name               = "${var.name}-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.eks_assume.json
}

resource "aws_iam_role_policy_attachment" "cluster" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_eks_cluster" "this" {
  name                          = var.name
  role_arn                      = aws_iam_role.cluster.arn
  version                       = var.cluster_version
  bootstrap_self_managed_addons = false

  deletion_protection = true

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = var.public_access_cidrs
  }

  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster
  ]
}

resource "aws_eks_access_entry" "cluster_admin" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = var.cluster_admin_role_arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "cluster_admin" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = aws_eks_access_entry.cluster_admin.principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}

data "aws_iam_policy_document" "node_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "node" {
  name               = "${var.name}-node-role"
  assume_role_policy = data.aws_iam_policy_document.node_assume.json
}

resource "aws_iam_role_policy_attachment" "worker" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "ecr" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
}

resource "aws_iam_role_policy_attachment" "cni" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

locals {
  private_subnets_by_az = zipmap(
    var.availability_zones,
    var.private_subnet_ids
  )

  system_subnets_by_az = {
    for az, subnet in local.private_subnets_by_az :
    az => subnet
    if contains(slice(var.availability_zones, 0, 2), az)
  }
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "vpc-cni"

  depends_on = [
    aws_iam_role_policy_attachment.cni
  ]
}

resource "aws_eks_node_group" "system" {
  for_each = local.system_subnets_by_az

  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.name}-system-${each.key}"
  node_role_arn   = aws_iam_role.node.arn

  subnet_ids     = [each.value]
  instance_types = var.node_instance_types
  version        = aws_eks_cluster.this.version
  capacity_type  = "ON_DEMAND"

  labels = {
    pool = "system"
  }

  taint {
    key    = "dedicated"
    value  = "system"
    effect = "NO_SCHEDULE"
  }

  scaling_config {
    desired_size = 1
    min_size     = 1
    max_size     = var.system_max_per_az
  }

  lifecycle {
    ignore_changes = [
      scaling_config[0].desired_size
    ]
  }

  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.worker,
    aws_iam_role_policy_attachment.ecr,
    aws_iam_role_policy_attachment.cni,
    aws_eks_addon.vpc_cni
  ]
}

resource "aws_eks_node_group" "application" {
  for_each = local.private_subnets_by_az

  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.name}-application-${each.key}"
  node_role_arn   = aws_iam_role.node.arn

  subnet_ids     = [each.value]
  instance_types = var.node_instance_types
  version        = aws_eks_cluster.this.version
  capacity_type  = "ON_DEMAND"

  labels = {
    pool = "application"
  }

  scaling_config {
    desired_size = 1
    min_size     = 1
    max_size     = var.app_max_per_az
  }

  lifecycle {
    ignore_changes = [
      scaling_config[0].desired_size
    ]
  }

  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.worker,
    aws_iam_role_policy_attachment.ecr,
    aws_iam_role_policy_attachment.cni,
    aws_eks_addon.vpc_cni
  ]
}

resource "aws_eks_addon" "core" {
  for_each = toset([
    "coredns",
    "kube-proxy"
  ])

  cluster_name = aws_eks_cluster.this.name
  addon_name   = each.key

  depends_on = [
    aws_eks_node_group.system,
    aws_eks_node_group.application
  ]
}

resource "aws_eks_addon" "pod_identity_agent" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "eks-pod-identity-agent"

  depends_on = [
    aws_eks_node_group.system,
    aws_eks_node_group.application
  ]
}
