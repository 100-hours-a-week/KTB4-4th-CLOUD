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
  name     = var.name
  role_arn = aws_iam_role.cluster.arn
  version  = var.cluster_version
  vpc_config {
    subnet_ids              = var.private_subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = true
  }
  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"
  }
  depends_on = [aws_iam_role_policy_attachment.cluster]
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
resource "aws_eks_node_group" "system" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.name}-system"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.private_subnet_ids
  instance_types  = var.node_instance_types
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
    desired_size = var.system_desired
    min_size     = 2
    max_size     = 3
  }
  update_config {
    max_unavailable = 1
  }
  depends_on = [aws_iam_role_policy_attachment.worker, aws_iam_role_policy_attachment.ecr, aws_iam_role_policy_attachment.cni]
}
resource "aws_eks_node_group" "application" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.name}-application"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.private_subnet_ids
  instance_types  = var.node_instance_types
  capacity_type   = "ON_DEMAND"
  labels = {
    pool = "application"
  }
  scaling_config {
    desired_size = var.app_desired
    min_size     = 2
    max_size     = 4
  }
  update_config {
    max_unavailable = 1
  }
  depends_on = [aws_iam_role_policy_attachment.worker, aws_iam_role_policy_attachment.ecr, aws_iam_role_policy_attachment.cni]
}
