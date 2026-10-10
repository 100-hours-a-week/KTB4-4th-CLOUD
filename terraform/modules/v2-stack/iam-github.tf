# GitHub Actions가 OIDC로 배포 Role을 맡을 수 있도록 허용하는 신뢰 정책
data "aws_iam_policy_document" "github_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [var.github_oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repository}:environment:${var.environment}"]
    }
  }
}

# GitHub Actions에서 ECS 배포를 수행할 때 사용하는 Role
resource "aws_iam_role" "github_cd" {
  name               = "needu-${var.environment}-github-ecs-cd"
  assume_role_policy = data.aws_iam_policy_document.github_assume.json
}

# ECS 서비스 배포와 Task Role 전달에 필요한 권한을 배포 Role에 부여
resource "aws_iam_role_policy" "github_cd" {
  name = "ecs-deploy"
  role = aws_iam_role.github_cd.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Allow", Action = ["ecs:DescribeServices", "ecs:UpdateService", "ecs:DescribeTaskDefinition", "ecs:RegisterTaskDefinition", "ecs:DescribeTasks", "ecs:ListTasks"], Resource = "*" },
    { Effect = "Allow", Action = ["iam:PassRole"], Resource = concat([aws_iam_role.execution.arn], [for r in aws_iam_role.task : r.arn]), Condition = { StringEquals = { "iam:PassedToService" = "ecs-tasks.amazonaws.com" } } },
    { Effect = "Allow", Action = ["ecr:BatchGetImage", "ecr:DescribeImages", "ecr:GetAuthorizationToken"], Resource = "*" }
  ] })
}

# 현재 AWS 계정 ID를 조회해 ECR Repository ARN을 구성할 때 사용
data "aws_caller_identity" "current" {}

# main과 develop 브랜치의 GitHub Actions가 CI Role을 맡도록 허용
data "aws_iam_policy_document" "github_ci_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [var.github_oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repository}:ref:refs/heads/main", "repo:${var.github_repository}:ref:refs/heads/develop"]
    }
  }
}

# GitHub Actions에서 컨테이너 이미지를 빌드하고 ECR에 올릴 때 사용하는 Role
resource "aws_iam_role" "github_ci" {
  name               = "needu-${var.environment}-github-ecr-ci"
  assume_role_policy = data.aws_iam_policy_document.github_ci_assume.json
}

# Frontend, Backend, AI 이미지를 각 ECR Repository에 업로드할 권한을 부여
resource "aws_iam_role_policy" "github_ci" {
  name = "ecr-push"
  role = aws_iam_role.github_ci.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Allow", Action = ["ecr:GetAuthorizationToken"], Resource = "*" },
    { Effect = "Allow", Action = ["ecr:BatchCheckLayerAvailability", "ecr:CompleteLayerUpload", "ecr:InitiateLayerUpload", "ecr:PutImage", "ecr:UploadLayerPart", "ecr:BatchGetImage", "ecr:DescribeImages"], Resource = [for service in ["frontend", "backend", "ai"] : "arn:aws:ecr:ap-northeast-2:${data.aws_caller_identity.current.account_id}:repository/need-u/${service}"] }
  ] })
}
