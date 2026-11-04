# V3 Plan Role은 Apply Role과 별도로 생성되어 있다. 기존 Role에
# Terraform refresh와 ESO용 RDS Secret ARN 조회에 필요한 읽기 권한만 부여한다.
data "aws_iam_policy_document" "v3_plan_eso_read" {
  statement {
    sid       = "DescribeDevPodIdentityAssociations"
    actions   = ["eks:DescribePodIdentityAssociation"]
    resources = ["arn:aws:eks:ap-northeast-2:919551759796:podidentityassociation/needu-v3-dev/*"]
  }

  statement {
    sid     = "DescribeDevRDSInstances"
    actions = ["rds:DescribeDBInstances"]
    resources = [
      "arn:aws:rds:ap-northeast-2:919551759796:db:needu-dev-mysql",
      "arn:aws:rds:ap-northeast-2:919551759796:db:needu-dev-postgres",
    ]
  }

  statement {
    sid       = "DescribeDevValkeyReplicationGroup"
    actions   = ["elasticache:DescribeReplicationGroups"]
    resources = ["arn:aws:elasticache:ap-northeast-2:919551759796:replicationgroup:needu-v3-dev-valkey"]
  }

  statement {
    sid       = "ReadExternalSecretsRolePolicy"
    actions   = ["iam:GetRolePolicy", "iam:ListRolePolicies"]
    resources = ["arn:aws:iam::919551759796:role/needu-v3-dev-external-secrets"]
  }
}

resource "aws_iam_role_policy" "v3_plan_eso_read" {
  name   = "TerraformV3ESOPlanRead"
  role   = "NeedU-V3-Terraform-Plan"
  policy = data.aws_iam_policy_document.v3_plan_eso_read.json
}
