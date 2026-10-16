locals {
  terraform_github_repository = "100-hours-a-week/KTB4-4th-CLOUD"

  terraform_oidc_provider_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"

  terraform_state_bucket = "needu-terraform-state-${data.aws_caller_identity.current.account_id}"

  terraform_roles = {
    plan = {
      name        = "NeedU-V2-Terraform-Plan"
      environment = "terraform-plan"
      state_keys = [
        "shared/terraform.tfstate",
        "v2/dev/terraform.tfstate",
        "v2/staging/terraform.tfstate",
        "v2/prod/terraform.tfstate"
      ]
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

# --------------------------------------------------
# Existing GitHub Actions OIDC Provider
# --------------------------------------------------

data "aws_iam_openid_connect_provider" "github_actions_terraform" {
  arn = local.terraform_oidc_provider_arn
}

# --------------------------------------------------
# GitHub Actions OIDC Trust Policy
# --------------------------------------------------

data "aws_iam_policy_document" "terraform_github_trust" {
  for_each = local.terraform_roles

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

# --------------------------------------------------
# Terraform IAM Roles
# --------------------------------------------------

resource "aws_iam_role" "terraform_github" {
  for_each = local.terraform_roles

  name               = each.value.name
  assume_role_policy = data.aws_iam_policy_document.terraform_github_trust[each.key].json

  tags = {
    Project     = "NeedU"
    ManagedBy   = "Terraform"
    Purpose     = "TerraformGitHubActions"
    Environment = each.key
  }
}

# --------------------------------------------------
# Terraform Remote State Access Policy
# --------------------------------------------------

data "aws_iam_policy_document" "terraform_state" {
  for_each = local.terraform_roles

  statement {
    sid       = "ListEnvironmentStateObjects"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${local.terraform_state_bucket}"]

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
    sid     = "ReadEnvironmentState"
    effect  = "Allow"
    actions = ["s3:GetObject"]

    resources = [
      for key in each.value.state_keys :
      "arn:aws:s3:::${local.terraform_state_bucket}/${key}"
    ]
  }

  dynamic "statement" {
    for_each = each.value.can_write_state ? [1] : []

    content {
      sid     = "WriteEnvironmentState"
      effect  = "Allow"
      actions = ["s3:PutObject"]

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

# --------------------------------------------------
# Attach Remote State Policy
# --------------------------------------------------

resource "aws_iam_role_policy" "terraform_state" {
  for_each = local.terraform_roles

  name   = "TerraformEnvironmentState"
  role   = aws_iam_role.terraform_github[each.key].id
  policy = data.aws_iam_policy_document.terraform_state[each.key].json
}

# --------------------------------------------------
# Shared Terraform - Amazon Managed Grafana
# --------------------------------------------------

data "aws_iam_policy_document" "terraform_shared_grafana" {

  # Workspace 생성 및 생성 시 태깅
  statement {
    sid    = "CreateGrafanaWorkspace"
    effect = "Allow"

    actions = [
      "grafana:CreateWorkspace",
      "grafana:TagResource"
    ]

    resources = ["*"]
  }

  # 생성된 Workspace 관리 및 설정 조회
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
  role   = aws_iam_role.terraform_github["shared"].id
  policy = data.aws_iam_policy_document.terraform_shared_grafana.json
}

# --------------------------------------------------
# Outputs
# --------------------------------------------------

output "terraform_github_role_arns" {
  description = "GitHub Actions Terraform IAM Role ARNs"

  value = {
    for key, role in aws_iam_role.terraform_github :
    key => role.arn
  }
}

# --------------------------------------------------
# Shared Terraform - Grafana Workspace IAM Role
# --------------------------------------------------

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
  role   = aws_iam_role.terraform_github["shared"].id
  policy = data.aws_iam_policy_document.terraform_shared_grafana_iam.json
}

# --------------------------------------------------
# Shared Terraform - Grafana IAM Identity Center Access
# --------------------------------------------------

data "aws_iam_policy_document" "terraform_shared_grafana_sso" {

  statement {
    sid    = "DescribeGrafanaSSORegions"
    effect = "Allow"

    actions = [
      "sso:DescribeRegisteredRegions"
    ]

    resources = ["*"]
  }

  # Workspace 생성 과정의 SSO 관리형 애플리케이션 생성 권한
  # 현재 Resource 범위 문제 진단을 위해 "*" 사용
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
  role   = aws_iam_role.terraform_github["shared"].id
  policy = data.aws_iam_policy_document.terraform_shared_grafana_sso.json
}