# ==================================================
# NeedU V2 Dev - SSM Bastion Permissions Boundary
# ==================================================

data "aws_iam_policy_document" "ssm_bastion_boundary" {
  statement {
    sid    = "AllowSSMManagedInstance"
    effect = "Allow"

    actions = [
      "ssm:UpdateInstanceInformation",

      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel",

      "ec2messages:AcknowledgeMessage",
      "ec2messages:DeleteMessage",
      "ec2messages:FailMessage",
      "ec2messages:GetEndpoint",
      "ec2messages:GetMessages",
      "ec2messages:SendReply"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_policy" "ssm_bastion_boundary" {
  name        = "NeedU-V2-dev-SSMBastionPermissionsBoundary"
  description = "Permissions boundary for NeedU Dev SSM Bastion"

  policy = data.aws_iam_policy_document.ssm_bastion_boundary.json

  tags = {
    Name = "NeedU-V2-dev-SSMBastionPermissionsBoundary"
  }
}