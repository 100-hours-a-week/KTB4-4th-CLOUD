data "aws_iam_policy_document" "ecs_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}
resource "aws_iam_role" "execution" {
  name               = "needu-${var.environment}-ecs-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
}
resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
resource "aws_iam_role_policy" "execution_parameters" {
  name   = "needu-${var.environment}-execution-parameters"
  role   = aws_iam_role.execution.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Action = ["ssm:GetParameters", "ssm:GetParameter", "secretsmanager:GetSecretValue"], Resource = ["arn:aws:ssm:*:*:parameter${var.parameter_prefix}/*", aws_db_instance.mysql.master_user_secret[0].secret_arn, aws_db_instance.postgres.master_user_secret[0].secret_arn] }] })
}
resource "aws_iam_role" "task" {
  for_each           = toset(["frontend", "backend", "ai"])
  name               = "needu-${var.environment}-${each.key}-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
}
resource "aws_iam_role_policy" "task_catalog" {
  name   = "catalog-access"
  role   = aws_iam_role.task["ai"].id
  policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Action = ["s3:ListBucket"], Resource = [aws_s3_bucket.catalog.arn] }, { Effect = "Allow", Action = ["s3:GetObject", "s3:PutObject"], Resource = ["${aws_s3_bucket.catalog.arn}/*"] }] })
}
resource "aws_iam_role_policy" "task_secrets" {
  for_each = toset(["backend", "ai"])
  name     = "database-secret-read"
  role     = aws_iam_role.task[each.key].id
  policy   = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Action = ["secretsmanager:GetSecretValue"], Resource = each.key == "backend" ? [aws_db_instance.mysql.master_user_secret[0].secret_arn] : [aws_db_instance.postgres.master_user_secret[0].secret_arn, aws_db_instance.mysql.master_user_secret[0].secret_arn] }] })
}
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
resource "aws_iam_role" "github_cd" {
  name               = "needu-${var.environment}-github-ecs-cd"
  assume_role_policy = data.aws_iam_policy_document.github_assume.json
}
resource "aws_iam_role_policy" "github_cd" {
  name = "ecs-deploy"
  role = aws_iam_role.github_cd.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Allow", Action = ["ecs:DescribeServices", "ecs:UpdateService", "ecs:DescribeTaskDefinition", "ecs:RegisterTaskDefinition", "ecs:DescribeTasks", "ecs:ListTasks"], Resource = "*" },
    { Effect = "Allow", Action = ["iam:PassRole"], Resource = concat([aws_iam_role.execution.arn], [for r in aws_iam_role.task : r.arn]), Condition = { StringEquals = { "iam:PassedToService" = "ecs-tasks.amazonaws.com" } } },
    { Effect = "Allow", Action = ["ecr:BatchGetImage", "ecr:DescribeImages", "ecr:GetAuthorizationToken"], Resource = "*" }
  ] })
}

data "aws_caller_identity" "current" {}
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
resource "aws_iam_role" "github_ci" {
  name               = "needu-${var.environment}-github-ecr-ci"
  assume_role_policy = data.aws_iam_policy_document.github_ci_assume.json
}
resource "aws_iam_role_policy" "github_ci" {
  name = "ecr-push"
  role = aws_iam_role.github_ci.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Allow", Action = ["ecr:GetAuthorizationToken"], Resource = "*" },
    { Effect = "Allow", Action = ["ecr:BatchCheckLayerAvailability", "ecr:CompleteLayerUpload", "ecr:InitiateLayerUpload", "ecr:PutImage", "ecr:UploadLayerPart", "ecr:BatchGetImage", "ecr:DescribeImages"], Resource = [for service in ["frontend", "backend", "ai"] : "arn:aws:ecr:ap-northeast-2:${data.aws_caller_identity.current.account_id}:repository/need-u/${service}"] }
  ] })
}
