resource "aws_prometheus_workspace" "prod" {
  alias = "${module.eks.cluster_name}-monitoring"

  tags = {
    Name = "${module.eks.cluster_name}-monitoring"
  }
}

data "aws_iam_policy_document" "adot_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "adot" {
  name               = "${module.eks.cluster_name}-adot"
  assume_role_policy = data.aws_iam_policy_document.adot_assume.json
}

data "aws_iam_policy_document" "adot_amp_write" {
  statement {
    sid       = "WriteProdAMP"
    effect    = "Allow"
    actions   = ["aps:RemoteWrite"]
    resources = [aws_prometheus_workspace.prod.arn]
  }
}

resource "aws_iam_role_policy" "adot_amp_write" {
  name   = "WriteNeedUV3ProdAMP"
  role   = aws_iam_role.adot.name
  policy = data.aws_iam_policy_document.adot_amp_write.json
}

resource "aws_eks_pod_identity_association" "adot" {
  cluster_name    = module.eks.cluster_name
  namespace       = "monitoring"
  service_account = "adot-collector"
  role_arn        = aws_iam_role.adot.arn

  depends_on = [aws_iam_role_policy.adot_amp_write]
}
