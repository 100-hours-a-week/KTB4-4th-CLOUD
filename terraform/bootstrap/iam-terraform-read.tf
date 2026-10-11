
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
    "ssm:DescribeParameters",
    "secretsmanager:DescribeSecret",
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

  statement {
    sid    = "ReadCatalogBucketConfiguration"
    effect = "Allow"

    actions = [
      "s3:GetBucketVersioning",
      "s3:GetEncryptionConfiguration",
      "s3:GetBucketPublicAccessBlock",
      "s3:GetBucketTagging",
      "s3:ListBucket"
    ]

    resources = [
      "arn:aws:s3:::needu-dev-catalog-*",
      "arn:aws:s3:::needu-staging-catalog-*",
      "arn:aws:s3:::needu-prod-catalog-*"
    ]
  }
}

resource "aws_iam_role_policy" "terraform_read" {
  for_each = local.terraform_roles

  name   = "TerraformResourceRead"
  role   = aws_iam_role.terraform_github[each.key].id
  policy = data.aws_iam_policy_document.terraform_read.json
}
