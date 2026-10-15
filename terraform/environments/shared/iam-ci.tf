
# --------------------------------------------------
# GitHub OIDC Provider (Existing)
# --------------------------------------------------

data "aws_iam_openid_connect_provider" "github" {
  arn = "arn:aws:iam::919551759796:oidc-provider/token.actions.githubusercontent.com"
}

data "aws_caller_identity" "current" {}

# --------------------------------------------------
# Common CI Trust Policy (Backend / AI)
# --------------------------------------------------

data "aws_iam_policy_document" "github_actions_ci_trust" {
  statement {
    sid     = "GitHubActionsOIDC"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type = "Federated"
      identifiers = [
        data.aws_iam_openid_connect_provider.github.arn
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
        "repo:100-hours-a-week@167328634/KTB4-4th-BE@1344652257:ref:refs/heads/dev",
        "repo:100-hours-a-week@167328634/KTB4-4th-AI@1344652688:ref:refs/heads/dev"
      ]
    }
  }
}

# --------------------------------------------------
# Common CI Role (Backend / AI)
# --------------------------------------------------

resource "aws_iam_role" "github_actions_ci" {
  name = "NeedU-V2-GitHubActions-CI"

  assume_role_policy = data.aws_iam_policy_document.github_actions_ci_trust.json

  tags = {
    Name      = "NeedU-V2-GitHubActions-CI"
    Project   = "needu"
    ManagedBy = "terraform"
  }
}

# --------------------------------------------------
# Common ECR Push Policy (Backend / AI)
# --------------------------------------------------

data "aws_iam_policy_document" "ecr_push" {
  statement {
    sid       = "ECRLogin"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid    = "ECRPush"
    effect = "Allow"

    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
      "ecr:CompleteLayerUpload",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart"
    ]

    resources = [
      aws_ecr_repository.backend.arn,
      aws_ecr_repository.ai.arn
    ]
  }
}

resource "aws_iam_policy" "ecr_push" {
  name   = "NeedU-V2-ECR-Push"
  policy = data.aws_iam_policy_document.ecr_push.json

  tags = {
    Project   = "needu"
    ManagedBy = "terraform"
  }
}

resource "aws_iam_role_policy_attachment" "ecr_push" {
  role       = aws_iam_role.github_actions_ci.name
  policy_arn = aws_iam_policy.ecr_push.arn
}

# --------------------------------------------------
# Frontend CI Trust Policy
# --------------------------------------------------

data "aws_iam_policy_document" "github_actions_frontend_ci_trust" {
  statement {
    sid     = "GitHubActionsFrontendOIDC"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type = "Federated"
      identifiers = [
        data.aws_iam_openid_connect_provider.github.arn
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
        "repo:100-hours-a-week@167328634/KTB4-4th-FE@1344651837:ref:refs/heads/dev"
      ]
    }
  }
}

# --------------------------------------------------
# Frontend CI Role
# --------------------------------------------------

resource "aws_iam_role" "github_actions_frontend_ci" {
  name = "NeedU-V2-GitHubActions-CI-Frontend"

  assume_role_policy = data.aws_iam_policy_document.github_actions_frontend_ci_trust.json

  tags = {
    Name      = "NeedU-V2-GitHubActions-CI-Frontend"
    Project   = "needu"
    ManagedBy = "terraform"
  }
}

# --------------------------------------------------
# Frontend ECR Push Policy
# --------------------------------------------------

data "aws_iam_policy_document" "frontend_ecr_push" {
  statement {
    sid       = "ECRLogin"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid    = "FrontendECRPush"
    effect = "Allow"

    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
      "ecr:CompleteLayerUpload",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart"
    ]

    resources = [
      aws_ecr_repository.frontend.arn
    ]
  }
}

resource "aws_iam_policy" "frontend_ecr_push" {
  name   = "NeedU-V2-Frontend-ECR-Push"
  policy = data.aws_iam_policy_document.frontend_ecr_push.json

  tags = {
    Project   = "needu"
    ManagedBy = "terraform"
  }
}

resource "aws_iam_role_policy_attachment" "frontend_ecr_push" {
  role       = aws_iam_role.github_actions_frontend_ci.name
  policy_arn = aws_iam_policy.frontend_ecr_push.arn
}

# --------------------------------------------------
# Frontend Build SSM Read Policy
# --------------------------------------------------

data "aws_iam_policy_document" "frontend_build_ssm" {
  statement {
    sid    = "ReadFrontendBuildParameters"
    effect = "Allow"

    actions = [
      "ssm:GetParametersByPath",
      "ssm:GetParameter",
      "ssm:GetParameters"
    ]

    resources = [
      "arn:aws:ssm:ap-northeast-2:${data.aws_caller_identity.current.account_id}:parameter/needu/common/frontend-build",
      "arn:aws:ssm:ap-northeast-2:${data.aws_caller_identity.current.account_id}:parameter/needu/common/frontend-build/*"
    ]
  }
}

resource "aws_iam_policy" "frontend_build_ssm" {
  name   = "NeedU-V2-Frontend-Build-SSM-Read"
  policy = data.aws_iam_policy_document.frontend_build_ssm.json

  tags = {
    Project   = "needu"
    ManagedBy = "terraform"
  }
}

resource "aws_iam_role_policy_attachment" "frontend_build_ssm" {
  role       = aws_iam_role.github_actions_frontend_ci.name
  policy_arn = aws_iam_policy.frontend_build_ssm.arn
}

# --------------------------------------------------
# Outputs
# --------------------------------------------------

output "github_actions_ci_role_arn" {
  description = "V2 Backend / AI GitHub Actions CI Role ARN"
  value       = aws_iam_role.github_actions_ci.arn
}

output "github_actions_frontend_ci_role_arn" {
  description = "V2 Frontend GitHub Actions CI Role ARN"
  value       = aws_iam_role.github_actions_frontend_ci.arn
}
