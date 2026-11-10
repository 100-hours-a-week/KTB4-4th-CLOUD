locals {
  v3_prod_promotion_services = {
    ai = {
      role_name          = "NeedU-V3-Prod-GitHubActions-AI"
      oidc_subject       = "repo:100-hours-a-week@167328634/KTB4-4th-AI@1344652688:environment:prod"
      ecr_repository_arn = aws_ecr_repository.ai.arn
    }
    frontend = {
      role_name          = "NeedU-V3-Prod-GitHubActions-FE"
      oidc_subject       = "repo:100-hours-a-week@167328634/KTB4-4th-FE@1344651837:environment:prod"
      ecr_repository_arn = aws_ecr_repository.frontend.arn
    }
    backend = {
      role_name          = "NeedU-V3-Prod-GitHubActions-BE"
      oidc_subject       = "repo:100-hours-a-week@167328634/KTB4-4th-BE@1344652257:environment:prod"
      ecr_repository_arn = aws_ecr_repository.backend.arn
    }
  }
}

data "aws_iam_policy_document" "v3_prod_promotion_trust" {
  for_each = local.v3_prod_promotion_services

  statement {
    sid     = "GitHubActionsProdEnvironmentOIDC"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [each.value.oidc_subject]
    }
  }
}

resource "aws_iam_role" "v3_prod_promotion" {
  for_each = local.v3_prod_promotion_services

  name               = each.value.role_name
  assume_role_policy = data.aws_iam_policy_document.v3_prod_promotion_trust[each.key].json

  tags = {
    Name        = each.value.role_name
    Project     = "needu"
    Environment = "prod"
    ManagedBy   = "terraform"
  }
}

data "aws_iam_policy_document" "v3_prod_promotion_ecr_read" {
  for_each = local.v3_prod_promotion_services

  statement {
    sid       = "ReadProductionImageMetadata"
    effect    = "Allow"
    actions   = ["ecr:DescribeImages"]
    resources = [each.value.ecr_repository_arn]
  }
}

resource "aws_iam_role_policy" "v3_prod_promotion_ecr_read" {
  for_each = local.v3_prod_promotion_services

  name   = "ReadProductionECRImageMetadata"
  role   = aws_iam_role.v3_prod_promotion[each.key].name
  policy = data.aws_iam_policy_document.v3_prod_promotion_ecr_read[each.key].json
}

output "v3_prod_promotion_role_arns" {
  description = "GitHub Actions OIDC roles used to promote V3 production images"
  value = {
    for service, role in aws_iam_role.v3_prod_promotion : service => role.arn
  }
}
