# V2 Dev RDS 보안 그룹에 대한 V3 Apply Role 권한만 추가한다.
# 조회 결과가 없거나 둘 이상이면 Plan이 실패해 다른 보안 그룹을 수정하지 않는다.
locals {
  dev_vpc_id = "vpc-0f2478c01e376b1b6"
}

data "aws_security_group" "dev_mysql" {
  vpc_id = local.dev_vpc_id

  filter {
    name   = "group-name"
    values = ["needu-dev-mysql-*"]
  }
}

data "aws_security_group" "dev_postgres" {
  vpc_id = local.dev_vpc_id

  filter {
    name   = "group-name"
    values = ["needu-dev-postgres-*"]
  }
}

data "aws_iam_policy_document" "dev_rds_ingress" {
  statement {
    sid     = "ManageV3EKSIngressOnDevRDS"
    actions = ["ec2:AuthorizeSecurityGroupIngress", "ec2:RevokeSecurityGroupIngress"]
    resources = [
      data.aws_security_group.dev_mysql.arn,
      data.aws_security_group.dev_postgres.arn,
    ]
  }
}

resource "aws_iam_role_policy" "dev_rds_ingress" {
  name   = "TerraformV3DevRDSIngress"
  role   = aws_iam_role.v3_dev_apply.name
  policy = data.aws_iam_policy_document.dev_rds_ingress.json
}
