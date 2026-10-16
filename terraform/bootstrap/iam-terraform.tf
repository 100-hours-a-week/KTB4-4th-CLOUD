
locals {
  terraform_github_repository = "100-hours-a-week/KTB4-4th-CLOUD"

  terraform_github_oidc_provider_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"

  terraform_state_bucket = "needu-terraform-state-${data.aws_caller_identity.current.account_id}"

  terraform_github_roles = {
    plan = {
      name            = "NeedU-V2-Terraform-Plan"
      environment     = "terraform-plan"
      state_keys      = ["shared/terraform.tfstate", "v2/dev/terraform.tfstate", "v2/staging/terraform.tfstate", "v2/prod/terraform.tfstate"]
      can_write_state = false
      can_lock_state  = true
    }

    shared = {
      name            = "NeedU-V2-Terraform-Shared"
      environment     = "terraform-shared"
      state_keys      = ["shared/terraform.tfstate"]
      can_write_state = true
      can_lock_state  = true
    }

    dev = {
      name            = "NeedU-V2-Terraform-Dev"
      environment     = "dev"
      state_keys      = ["v2/dev/terraform.tfstate"]
      can_write_state = true
      can_lock_state  = true
    }

    staging = {
      name            = "NeedU-V2-Terraform-Staging"
      environment     = "staging"
      state_keys      = ["v2/staging/terraform.tfstate"]
      can_write_state = true
      can_lock_state  = true
    }

    prod = {
      name            = "NeedU-V2-Terraform-Prod"
      environment     = "production"
      state_keys      = ["v2/prod/terraform.tfstate"]
      can_write_state = true
      can_lock_state  = true
    }
  }
}

# ============================================================
# GitHub Actions OIDC
# ============================================================

data "aws_iam_openid_connect_provider" "github_actions_terraform" {
  arn = local.terraform_github_oidc_provider_arn
}

data "aws_iam_policy_document" "terraform_github_trust" {
  for_each = local.terraform_github_roles

  statement {
    sid     = "GitHubEnvironmentOnly"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type = "Federated"
      identifiers = [
        data.aws_iam_openid_connect_provider.github_actions_terraform.arn
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"

      values = [
        "repo:100-hours-a-week@167328634/KTB4-4th-CLOUD@1344657749:environment:${each.value.environment}"
      ]
    }
  }
}

resource "aws_iam_role" "terraform_github" {
  for_each = local.terraform_github_roles

  name               = each.value.name
  assume_role_policy = data.aws_iam_policy_document.terraform_github_trust[each.key].json

  # 기존 IAM Role 태그 유지
  tags = {
    Environment = each.key
    ManagedBy   = "Terraform"
    Project     = "NeedU"
    Purpose     = "TerraformGitHubActions"
  }
}

# ============================================================
# Terraform State S3 Access
# ============================================================

data "aws_iam_policy_document" "terraform_state" {
  for_each = local.terraform_github_roles

  statement {
    sid    = "ListEnvironmentStateObjects"
    effect = "Allow"

    actions = [
      "s3:ListBucket"
    ]

    resources = [
      "arn:aws:s3:::${local.terraform_state_bucket}"
    ]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"

      values = concat(
        each.value.state_keys,
        [
          for key in each.value.state_keys :
          "${key}.tflock"
        ]
      )
    }
  }

  statement {
    sid    = "ReadEnvironmentState"
    effect = "Allow"

    actions = [
      "s3:GetObject"
    ]

    resources = [
      for key in each.value.state_keys :
      "arn:aws:s3:::${local.terraform_state_bucket}/${key}"
    ]
  }

  dynamic "statement" {
    for_each = each.value.can_write_state ? [1] : []

    content {
      sid    = "WriteEnvironmentState"
      effect = "Allow"

      actions = [
        "s3:PutObject"
      ]

      resources = [
        for key in each.value.state_keys :
        "arn:aws:s3:::${local.terraform_state_bucket}/${key}"
      ]
    }
  }

  dynamic "statement" {
    for_each = each.value.can_lock_state ? [1] : []

    content {
      sid    = "ManageEnvironmentStateLocks"
      effect = "Allow"

      actions = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ]

      resources = [
        for key in each.value.state_keys :
        "arn:aws:s3:::${local.terraform_state_bucket}/${key}.tflock"
      ]
    }
  }
}

resource "aws_iam_role_policy" "terraform_state" {
  for_each = local.terraform_github_roles

  # 기존 정책 이름 유지 (교체 방지)
  name   = "TerraformEnvironmentState"
  role   = aws_iam_role.terraform_github[each.key].name
  policy = data.aws_iam_policy_document.terraform_state[each.key].json
}

# ============================================================
# Shared Terraform Role - Grafana Workspace
# ============================================================

data "aws_iam_policy_document" "terraform_shared_grafana" {
  statement {
    sid    = "CreateGrafanaWorkspace"
    effect = "Allow"

    actions = [
      "grafana:CreateWorkspace",
      "grafana:TagResource"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "ManageGrafanaWorkspace"
    effect = "Allow"

    actions = [
      "grafana:DescribeWorkspace",
      "grafana:DescribeWorkspaceConfiguration",
      "grafana:UpdateWorkspace",
      "grafana:DeleteWorkspace",
      "grafana:TagResource",
      "grafana:UntagResource",
      "grafana:ListTagsForResource"
    ]

    resources = [
      "arn:aws:grafana:ap-northeast-2:${data.aws_caller_identity.current.account_id}:/workspaces/*"
    ]
  }
}

resource "aws_iam_role_policy" "terraform_shared_grafana" {
  name   = "TerraformSharedGrafana"
  role   = aws_iam_role.terraform_github["shared"].name
  policy = data.aws_iam_policy_document.terraform_shared_grafana.json
}

# ============================================================
# Shared Terraform Role - Grafana IAM
# ============================================================

data "aws_iam_policy_document" "terraform_shared_grafana_iam" {
  statement {
    sid    = "ManageGrafanaWorkspaceRole"
    effect = "Allow"

    actions = [
      "iam:CreateRole",
      "iam:GetRole",
      "iam:DeleteRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:ListRoleTags",
      "iam:ListAttachedRolePolicies",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy"
    ]

    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/needu-v2-grafana-workspace"
    ]
  }

  statement {
    sid    = "PassGrafanaWorkspaceRole"
    effect = "Allow"

    actions = [
      "iam:PassRole"
    ]

    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/needu-v2-grafana-workspace"
    ]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["grafana.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "terraform_shared_grafana_iam" {
  name   = "TerraformSharedGrafanaIAM"
  role   = aws_iam_role.terraform_github["shared"].name
  policy = data.aws_iam_policy_document.terraform_shared_grafana_iam.json
}

# ============================================================
# Shared Terraform Role - Grafana IAM Identity Center
# ============================================================

data "aws_iam_policy_document" "terraform_shared_grafana_sso" {
  statement {
    sid    = "DescribeGrafanaSSORegions"
    effect = "Allow"

    actions = [
      "sso:DescribeRegisteredRegions"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "CreateGrafanaManagedApplication"
    effect = "Allow"

    actions = [
      "sso:CreateManagedApplicationInstance"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "terraform_shared_grafana_sso" {
  name   = "TerraformSharedGrafanaSSO"
  role   = aws_iam_role.terraform_github["shared"].name
  policy = data.aws_iam_policy_document.terraform_shared_grafana_sso.json
}

# ============================================================
# Outputs
# ============================================================

output "terraform_github_role_arns" {
  description = "Terraform GitHub Actions IAM Role ARNs"

  value = {
    for key, role in aws_iam_role.terraform_github :
    key => role.arn
  }
}
