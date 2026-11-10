# Keep permissions for the V3 Production application Valkey cache separate
# from the inline Terraform Apply policy to avoid IAM role policy size limits.
data "aws_iam_policy_document" "v3_prod_valkey_cache" {
  statement {
    sid    = "CreateProdValkeyCacheSecurityGroup"
    effect = "Allow"
    actions = [
      "ec2:CreateSecurityGroup",
    ]
    resources = [
      "arn:aws:ec2:${local.region}:${local.account_id}:security-group/*",
      "arn:aws:ec2:${local.region}:${local.account_id}:vpc/vpc-0f2478c01e376b1b6",
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/Name"
      values   = ["needu-v3-prod-valkey-cache-sg"]
    }
  }

  statement {
    sid    = "TagProdValkeyCacheSecurityGroupOnCreation"
    effect = "Allow"
    actions = [
      "ec2:CreateTags",
    ]
    resources = ["arn:aws:ec2:${local.region}:${local.account_id}:security-group/*"]

    condition {
      test     = "StringEquals"
      variable = "ec2:CreateAction"
      values   = ["CreateSecurityGroup"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/Name"
      values   = ["needu-v3-prod-valkey-cache-sg"]
    }
  }

  statement {
    sid    = "ManageProdValkeyCacheSecurityGroup"
    effect = "Allow"
    actions = [
      "ec2:DeleteSecurityGroup",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupIngress",
    ]
    resources = ["arn:aws:ec2:${local.region}:${local.account_id}:security-group/*"]

    condition {
      test     = "StringEquals"
      variable = "ec2:ResourceTag/Name"
      values   = ["needu-v3-prod-valkey-cache-sg"]
    }
  }

  statement {
    sid       = "CreateProdValkeyCacheSecurityGroupRule"
    effect    = "Allow"
    actions   = ["ec2:AuthorizeSecurityGroupIngress"]
    resources = ["arn:aws:ec2:${local.region}:${local.account_id}:security-group-rule/*"]
  }

  statement {
    sid    = "ManageProdValkeyCacheSubnetGroup"
    effect = "Allow"
    actions = [
      "elasticache:CreateCacheSubnetGroup",
      "elasticache:DeleteCacheSubnetGroup",
      "elasticache:ModifyCacheSubnetGroup",
    ]
    resources = [
      "arn:aws:elasticache:${local.region}:${local.account_id}:subnetgroup:needu-v3-prod-valkey-a-subnets",
    ]
  }

  statement {
    sid    = "ManageProdValkeyCacheReplicationGroup"
    effect = "Allow"
    actions = [
      "elasticache:CreateReplicationGroup",
      "elasticache:DeleteReplicationGroup",
      "elasticache:ModifyReplicationGroup",
      "elasticache:AddTagsToResource",
      "elasticache:RemoveTagsFromResource",
    ]
    resources = [
      "arn:aws:elasticache:${local.region}:${local.account_id}:replicationgroup:needu-v3-prod-valkey-a",
    ]
  }
}

resource "aws_iam_policy" "v3_prod_valkey_cache" {
  name        = "NeedU-V3-Terraform-Prod-ValkeyCache"
  description = "Allows V3 Production Terraform to manage the dedicated Valkey cache"
  policy      = data.aws_iam_policy_document.v3_prod_valkey_cache.json
}

resource "aws_iam_role_policy_attachment" "v3_prod_valkey_cache" {
  role       = aws_iam_role.v3_prod_apply.name
  policy_arn = aws_iam_policy.v3_prod_valkey_cache.arn
}
