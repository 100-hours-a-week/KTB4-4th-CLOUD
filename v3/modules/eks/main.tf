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
  vpc_config {
    subnet_ids              = var.private_subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = var.public_access_cidrs
  }
  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"
  }
  depends_on = [aws_iam_role_policy_attachment.cluster]
}
# EKS 클러스터에 접근할 관리자 IAM Role 등록
resource "aws_eks_access_entry" "cluster_admin" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = var.cluster_admin_role_arn
  type          = "STANDARD"
}

# 관리자 IAM Role에 Kubernetes 클러스터 관리자 권한 부여
resource "aws_eks_access_policy_association" "cluster_admin" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = aws_eks_access_entry.cluster_admin.principal_arn

  policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

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
# One node group per AZ guarantees one initial System and Application node in each AZ.
# The per-AZ maximum of 2 allows Cluster Autoscaler to scale independently.
locals {
  private_subnets_by_az = {
    for idx, az in var.availability_zones : az => var.private_subnet_ids[idx]
  }
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "vpc-cni"
  depends_on   = [aws_iam_role_policy_attachment.cni]
}

resource "aws_eks_node_group" "system" {
  for_each        = local.private_subnets_by_az
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.name}-system-${each.key}"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = [each.value]
  instance_types  = var.node_instance_types
  version         = aws_eks_cluster.this.version
  capacity_type   = "ON_DEMAND"
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
      scaling_config[0].desired_size,
      scaling_config[0].min_size,
      scaling_config[0].max_size,
    ]
  }
  update_config {
    max_unavailable = 1
  }
  depends_on = [aws_iam_role_policy_attachment.worker, aws_iam_role_policy_attachment.ecr, aws_iam_role_policy_attachment.cni, aws_eks_addon.vpc_cni]
}

resource "aws_eks_node_group" "application" {
  for_each        = local.private_subnets_by_az
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.name}-application-${each.key}"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = [each.value]
  instance_types  = var.node_instance_types
  version         = aws_eks_cluster.this.version
  capacity_type   = "ON_DEMAND"
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
      scaling_config[0].desired_size,
      scaling_config[0].min_size,
      scaling_config[0].max_size,
    ]
  }
  update_config {
    max_unavailable = 1
  }
  depends_on = [aws_iam_role_policy_attachment.worker, aws_iam_role_policy_attachment.ecr, aws_iam_role_policy_attachment.cni, aws_eks_addon.vpc_cni]
}

resource "aws_eks_addon" "core" {
  for_each     = toset(["coredns", "kube-proxy"])
  cluster_name = aws_eks_cluster.this.name
  addon_name   = each.key

  depends_on = [aws_eks_node_group.system, aws_eks_node_group.application]
}

resource "aws_eks_addon" "pod_identity_agent" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "eks-pod-identity-agent"

  depends_on = [
    aws_eks_node_group.system,
    aws_eks_node_group.application
  ]
}

# Dev EKS 노드 그룹을 매일 22:00~09:00(Asia/Seoul)에 0대로 축소한다.
# 야간에는 최대 용량도 0으로 잠가 Cluster Autoscaler의 재확장을 막고,
# 아침에는 Terraform 변수에 정의된 최대 용량으로 복구한다.
# 제어 영역은 유지되며, 운영 클러스터에는 이 모듈이 적용되지 않는다.
locals {
  scheduled_node_groups = merge(
    {
      for az, node_group in aws_eks_node_group.system : "system-${az}" => {
        arn             = node_group.arn
        node_group_name = node_group.node_group_name
        max_size        = var.system_max_per_az
      }
    },
    {
      for az, node_group in aws_eks_node_group.application : "application-${az}" => {
        arn             = node_group.arn
        node_group_name = node_group.node_group_name
        max_size        = var.app_max_per_az
      }
    },
  )
}

data "aws_iam_policy_document" "scheduler_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["scheduler.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "scheduler" {
  name               = "${var.name}-node-scheduler-role"
  assume_role_policy = data.aws_iam_policy_document.scheduler_assume.json
}

data "aws_iam_policy_document" "scheduler_eks" {
  statement {
    actions   = ["eks:UpdateNodegroupConfig"]
    resources = [for node_group in local.scheduled_node_groups : node_group.arn]
  }
}

resource "aws_iam_role_policy" "scheduler_eks" {
  name   = "${var.name}-node-scheduler"
  role   = aws_iam_role.scheduler.id
  policy = data.aws_iam_policy_document.scheduler_eks.json
}

resource "aws_scheduler_schedule" "node_night_stop" {
  for_each = local.scheduled_node_groups

  name                         = "${each.value.node_group_name}-night-stop"
  schedule_expression          = "cron(0 22 * * ? *)"
  schedule_expression_timezone = "Asia/Seoul"

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:eks:updateNodegroupConfig"
    role_arn = aws_iam_role.scheduler.arn
    input = jsonencode({
      ClusterName   = aws_eks_cluster.this.name
      NodegroupName = each.value.node_group_name
      ScalingConfig = {
        MinSize     = 0
        DesiredSize = 0
        MaxSize     = 0
      }
    })
  }
}

resource "aws_scheduler_schedule" "node_morning_start" {
  for_each = local.scheduled_node_groups

  name                         = "${each.value.node_group_name}-morning-start"
  schedule_expression          = "cron(0 9 * * ? *)"
  schedule_expression_timezone = "Asia/Seoul"

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:eks:updateNodegroupConfig"
    role_arn = aws_iam_role.scheduler.arn
    input = jsonencode({
      ClusterName   = aws_eks_cluster.this.name
      NodegroupName = each.value.node_group_name
      ScalingConfig = {
        MinSize     = 1
        DesiredSize = 1
        MaxSize     = each.value.max_size
      }
    })
  }
}
