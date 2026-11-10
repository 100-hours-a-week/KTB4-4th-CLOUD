locals {
  terraform_shared_v3_prod_promotion_role_names = [
    "NeedU-V3-Prod-GitHubActions-AI",
    "NeedU-V3-Prod-GitHubActions-FE",
    "NeedU-V3-Prod-GitHubActions-BE"
  ]
}

data "aws_iam_policy_document" "terraform_shared_v3_prod_promotion" {
  statement {
    sid    = "ManageV3ProductionPromotionRoles"
    effect = "Allow"

    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:GetRole",
      "iam:ListRoleTags",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:UpdateAssumeRolePolicy"
    ]

    resources = [
      for role_name in local.terraform_shared_v3_prod_promotion_role_names :
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${role_name}"
    ]
  }

  statement {
    sid    = "ManageV3ProductionPromotionInlinePolicies"
    effect = "Allow"

    actions = [
      "iam:DeleteRolePolicy",
      "iam:GetRolePolicy",
      "iam:ListRolePolicies",
      "iam:PutRolePolicy"
    ]

    resources = [
      for role_name in local.terraform_shared_v3_prod_promotion_role_names :
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${role_name}"
    ]
  }
}

resource "aws_iam_policy" "terraform_shared_v3_prod_promotion" {
  name        = "NeedU-V2-Terraform-Shared-V3ProdPromotion"
  description = "Allows the shared Terraform role to manage only V3 production GitHub Actions promotion roles"
  policy      = data.aws_iam_policy_document.terraform_shared_v3_prod_promotion.json

  tags = {
    Name        = "NeedU-V2-Terraform-Shared-V3ProdPromotion"
    Environment = "shared"
    Project     = "needu"
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role_policy_attachment" "terraform_shared_v3_prod_promotion" {
  role       = aws_iam_role.terraform_github["shared"].name
  policy_arn = aws_iam_policy.terraform_shared_v3_prod_promotion.arn
}
