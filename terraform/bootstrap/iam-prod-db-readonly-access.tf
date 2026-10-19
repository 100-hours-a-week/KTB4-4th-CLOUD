locals {
  prod_db_readonly_user_names = toset([
    "finn",
    "zayn",
  ])

  # V2 VPC 내부에서 Prod RDS에 접근하는 공용 SSM bastion.
  # V1 Prod 인스턴스(i-071de18816cfae436)를 사용하지 않는다.
  prod_db_ssm_bastion_instance_id = "i-0fc4a029b4d5b90ca"
}

data "aws_iam_policy_document" "prod_db_readonly_access" {
  statement {
    sid    = "OpenProdDatabaseTunnel"
    effect = "Allow"

    actions = ["ssm:StartSession"]

    resources = [
      "arn:aws:ec2:ap-northeast-2:${data.aws_caller_identity.current.account_id}:instance/${local.prod_db_ssm_bastion_instance_id}",
      "arn:aws:ssm:ap-northeast-2::document/AWS-StartPortForwardingSessionToRemoteHost",
    ]
  }

  statement {
    sid    = "ManageOwnDatabaseTunnel"
    effect = "Allow"

    actions = [
      "ssm:ResumeSession",
      "ssm:TerminateSession",
    ]

    resources = [
      "arn:aws:ssm:*:${data.aws_caller_identity.current.account_id}:session/$${aws:username}-*",
    ]
  }
}

resource "aws_iam_policy" "prod_db_readonly_access" {
  name        = "NeedU-V2-Prod-DB-ReadOnly-SSM-Access"
  description = "Allows approved IAM users to open SSM port-forwarding sessions to the production DB bastion"
  policy      = data.aws_iam_policy_document.prod_db_readonly_access.json

  tags = {
    Project     = "NeedU"
    Environment = "prod"
    Purpose     = "ProdDBReadOnlyAccess"
  }
}

resource "aws_iam_user_policy_attachment" "prod_db_readonly_access" {
  for_each = local.prod_db_readonly_user_names

  user       = each.value
  policy_arn = aws_iam_policy.prod_db_readonly_access.arn
}
