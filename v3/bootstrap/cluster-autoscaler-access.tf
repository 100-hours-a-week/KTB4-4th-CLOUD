data "aws_iam_policy_document" "v3_cluster_autoscaler_access" {
  statement {
    sid = "ManageV3ClusterAutoscalerRole"

    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
    ]

    resources = [
      "arn:aws:iam::919551759796:role/needu-v3-dev-cluster-autoscaler",
    ]
  }

  statement {
    sid       = "PassV3ClusterAutoscalerRole"
    actions   = ["iam:PassRole"]
    resources = ["arn:aws:iam::919551759796:role/needu-v3-dev-cluster-autoscaler"]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "v3_cluster_autoscaler_access" {
  name        = "NeedU-V3-Terraform-Dev-ClusterAutoscaler"
  description = "Allows V3 Dev Terraform to manage the Cluster Autoscaler Pod Identity role"
  policy      = data.aws_iam_policy_document.v3_cluster_autoscaler_access.json
}

resource "aws_iam_role_policy_attachment" "v3_cluster_autoscaler_access" {
  role       = aws_iam_role.v3_dev_apply.name
  policy_arn = aws_iam_policy.v3_cluster_autoscaler_access.arn
}
