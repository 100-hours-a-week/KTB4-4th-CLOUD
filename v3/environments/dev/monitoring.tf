
# AMP Workspace
resource "aws_prometheus_workspace" "dev" {
  alias = "${module.eks.cluster_name}-monitoring"

  tags = {
    Name = "${module.eks.cluster_name}-monitoring"
  }
}

# EKS Pod Identity Trust Policy
data "aws_iam_policy_document" "adot_assume" {
  statement {
    effect = "Allow"

    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

# ADOT Collector IAM Role
resource "aws_iam_role" "adot" {
  name               = "${module.eks.cluster_name}-adot"
  assume_role_policy = data.aws_iam_policy_document.adot_assume.json
}

# AMP Remote Write 최소 권한
data "aws_iam_policy_document" "adot_amp_write" {
  statement {
    sid     = "WriteDevAMP"
    effect  = "Allow"
    actions = ["aps:RemoteWrite"]

    resources = [
      aws_prometheus_workspace.dev.arn
    ]
  }
}

resource "aws_iam_role_policy" "adot_amp_write" {
  name   = "WriteNeedUV3DevAMP"
  role   = aws_iam_role.adot.name
  policy = data.aws_iam_policy_document.adot_amp_write.json
}

# ADOT Collector Pod Identity
resource "aws_eks_pod_identity_association" "adot" {
  cluster_name    = module.eks.cluster_name
  namespace       = "monitoring"
  service_account = "adot-collector"
  role_arn        = aws_iam_role.adot.arn

  depends_on = [
    aws_iam_role_policy.adot_amp_write
  ]
}
