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

# ECS 서비스 배포와 서비스별 Execution/Task Role 전달에 필요한 권한을 부여
resource "aws_iam_role_policy" "github_cd" {
  name = "ecs-deploy"
  role = aws_iam_role.github_cd.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Allow", Action = ["ecs:DescribeServices", "ecs:UpdateService", "ecs:DescribeTaskDefinition", "ecs:RegisterTaskDefinition", "ecs:DescribeTasks", "ecs:ListTasks"], Resource = "*" },
    { Effect = "Allow", Action = ["iam:PassRole"], Resource = concat([for r in aws_iam_role.service_execution : r.arn], [for r in aws_iam_role.task : r.arn], [for r in aws_iam_role.catalog_task : r.arn]), Condition = { StringEquals = { "iam:PassedToService" = "ecs-tasks.amazonaws.com" } } },
    { Effect = "Allow", Action = ["ecr:BatchGetImage", "ecr:DescribeImages", "ecr:GetAuthorizationToken"], Resource = "*" }
  ] })
}
