# ==================================================
# NeedU V2 - Staging 전원 제어 Role
#
# GitHub Actions에서 Staging의 ECS와 RDS만 시작·정지한다.
# Terraform Apply Role과 분리해 다른 환경이나 리소스를 변경하지 못하게 한다.
# ==================================================

locals {
  staging_control_role_name = "NeedU-V2-Staging-Control"
}

data "aws_iam_policy_document" "staging_control_github_trust" {
  statement {
    sid     = "GitHubStagingEnvironmentOnly"
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
        "repo:100-hours-a-week@167328634/KTB4-4th-CLOUD@1344657749:environment:staging"
      ]
    }
  }
}

resource "aws_iam_role" "staging_control" {
  name               = local.staging_control_role_name
  assume_role_policy = data.aws_iam_policy_document.staging_control_github_trust.json

  tags = {
    Project     = "NeedU"
    ManagedBy   = "Terraform"
    Purpose     = "StagingPowerControl"
    Environment = "staging"
  }
}

data "aws_iam_policy_document" "staging_control" {
  # Staging ECS 서비스 실행 수만 변경한다.
  statement {
    sid    = "ManageStagingECSServices"
    effect = "Allow"

    actions = [
      "ecs:DescribeServices",
      "ecs:UpdateService"
    ]

    resources = [
      "arn:aws:ecs:ap-northeast-2:${data.aws_caller_identity.current.account_id}:service/needu-staging-cluster/needu-staging-frontend",
      "arn:aws:ecs:ap-northeast-2:${data.aws_caller_identity.current.account_id}:service/needu-staging-cluster/needu-staging-backend",
      "arn:aws:ecs:ap-northeast-2:${data.aws_caller_identity.current.account_id}:service/needu-staging-cluster/needu-staging-ai"
    ]
  }

  # Scalable Target ARN은 생성 시 AWS가 ID를 부여하므로 미리 고정할 수 없다.
  # 대신 ECS DesiredCount와 Staging 태그 조건으로 변경 대상을 제한한다.
  statement {
    sid    = "ManageStagingECSScaling"
    effect = "Allow"

    actions   = ["application-autoscaling:RegisterScalableTarget"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "application-autoscaling:service-namespace"
      values   = ["ecs"]
    }

    condition {
      test     = "StringEquals"
      variable = "application-autoscaling:scalable-dimension"
      values   = ["ecs:service:DesiredCount"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/Environment"
      values   = ["staging"]
    }
  }

  # 현재 Auto Scaling 설정 조회는 변경 권한 없이 전체 조회만 허용한다.
  statement {
    sid       = "ReadECSScalingStatus"
    effect    = "Allow"
    actions   = ["application-autoscaling:DescribeScalableTargets"]
    resources = ["*"]
  }

  # Staging MySQL과 PostgreSQL만 시작·정지한다.
  statement {
    sid    = "ManageStagingDatabases"
    effect = "Allow"

    actions = [
      "rds:StartDBInstance",
      "rds:StopDBInstance"
    ]

    resources = [
      "arn:aws:rds:ap-northeast-2:${data.aws_caller_identity.current.account_id}:db:needu-staging-mysql",
      "arn:aws:rds:ap-northeast-2:${data.aws_caller_identity.current.account_id}:db:needu-staging-postgres"
    ]
  }

  # RDS Waiter가 현재 상태를 확인할 때 필요하다.
  statement {
    sid       = "ReadStagingDatabaseStatus"
    effect    = "Allow"
    actions   = ["rds:DescribeDBInstances"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "staging_control" {
  name   = "StagingPowerControl"
  role   = aws_iam_role.staging_control.id
  policy = data.aws_iam_policy_document.staging_control.json
}

output "staging_control_role_arn" {
  description = "Staging ECS·RDS 시작 및 정지용 GitHub Actions IAM Role ARN"
  value       = aws_iam_role.staging_control.arn
}
