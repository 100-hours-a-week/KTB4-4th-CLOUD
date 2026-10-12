
# --------------------------------------------------
# Terraform AWS Resource Read Permissions
# --------------------------------------------------

locals {
  terraform_read_actions = [
    "ec2:Describe*",
    "elasticloadbalancing:Describe*",
    "ecs:Describe*",
    "ecs:List*",
    "servicediscovery:Get*",
    "servicediscovery:List*",
    "application-autoscaling:Describe*",
    "application-autoscaling:ListTagsForResource",
    "cloudwatch:Describe*",
    "cloudwatch:List*",
    "cloudwatch:Get*",
    "logs:Describe*",
    "logs:List*",
    "rds:Describe*",
    "rds:ListTagsForResource",
    "elasticache:Describe*",
    "elasticache:List*",
    "ecr:Describe*",
    "ecr:List*",
    "route53:Get*",
    "route53:List*",
    "iam:Get*",
    "iam:List*",

    # SSM Parameter 목록 조회
    "ssm:DescribeParameters",

    # Secrets Manager 메타데이터 조회
    "secretsmanager:DescribeSecret",

    # ACM 인증서 조회
    "acm:DescribeCertificate",
    "acm:ListCertificates",
    "acm:ListTagsForCertificate",

    # S3 조회
    "s3:ListAllMyBuckets",
    "s3:GetBucketLocation"
  ]
}

data "aws_iam_policy_document" "terraform_read" {
  statement {
    sid       = "ReadTerraformManagedResources"
    effect    = "Allow"
    actions   = local.terraform_read_actions
    resources = ["*"]
  }

  # 환경별 SSM Parameter 조회
  statement {
    sid    = "ReadV2SSMParameters"
    effect = "Allow"

    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
      "ssm:ListTagsForResource"
    ]

    resources = [
      "arn:aws:ssm:ap-northeast-2:${data.aws_caller_identity.current.account_id}:parameter/needu/v2/dev/*",
      "arn:aws:ssm:ap-northeast-2:${data.aws_caller_identity.current.account_id}:parameter/needu/v2/staging/*",
      "arn:aws:ssm:ap-northeast-2:${data.aws_caller_identity.current.account_id}:parameter/needu/v2/prod/*"
    ]
  }

  # Catalog S3 Bucket 설정 조회
  statement {
    sid    = "ReadCatalogBucketConfiguration"
    effect = "Allow"

    actions = [
      "s3:GetBucket*",
      "s3:GetAccelerateConfiguration",
      "s3:GetLifecycleConfiguration",
      "s3:GetReplicationConfiguration",
      "s3:GetEncryptionConfiguration",
      "s3:ListBucket"
    ]

    resources = [
      "arn:aws:s3:::needu-dev-catalog-*",
      "arn:aws:s3:::needu-staging-catalog-*",
      "arn:aws:s3:::needu-prod-catalog-*"
    ]
  }
}

# Plan / Shared / Dev / Staging / Prod Role에
# 공통 조회 정책 부여
resource "aws_iam_role_policy" "terraform_read" {
  for_each = local.terraform_roles

  name   = "TerraformResourceRead"
  role   = aws_iam_role.terraform_github[each.key].id
  policy = data.aws_iam_policy_document.terraform_read.json
}
