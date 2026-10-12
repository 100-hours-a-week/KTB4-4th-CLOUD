
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

  # S3 State 객체 조회
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

  # Terraform State 읽기
  statement {
    sid     = "ReadEnvironmentState"
    effect  = "Allow"
    actions = ["s3:GetObject"]

    resources = [
      for key in each.value.state_keys :
      "arn:aws:s3:::${local.terraform_state_bucket}/${key}"
    ]
  }

  # Terraform State 쓰기: Apply Role만
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

  # S3 Native State Lock
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
# Outputs
# --------------------------------------------------

output "terraform_github_role_arns" {
  description = "GitHub Actions Terraform IAM Role ARNs"

  value = {
    for key, role in aws_iam_role.terraform_github :
    key => role.arn
  }
}
