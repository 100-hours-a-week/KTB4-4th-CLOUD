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

  # Staging ALB cutover workflows inspect target health before changing listener rules.
  statement {
    sid    = "ReadStagingLoadBalancerStatus"
    effect = "Allow"

    actions = [
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeRules",
      "elasticloadbalancing:DescribeTags",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:DescribeTargetHealth"
    ]

    resources = ["*"]
  }

  # Only the listener and listener rules that belong to the Staging ALB can be changed.
  statement {
    sid    = "ManageStagingALBCutoverRules"
    effect = "Allow"

    actions = [
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:CreateRule",
      "elasticloadbalancing:DeleteRule",
      "elasticloadbalancing:ModifyRule"
    ]

    resources = [
      "arn:aws:elasticloadbalancing:ap-northeast-2:${data.aws_caller_identity.current.account_id}:listener/app/needu-staging-alb/*/*",
      "arn:aws:elasticloadbalancing:ap-northeast-2:${data.aws_caller_identity.current.account_id}:listener-rule/app/needu-staging-alb/*/*/*"
    ]
  }

  # Cutover 공통 도메인의 V1/V2 연결 대상만 변경할 수 있다.
  statement {
    sid    = "ChangeStagingCutoverRecord"
    effect = "Allow"

    actions   = ["route53:ChangeResourceRecordSets"]
    resources = ["arn:aws:route53:::hostedzone/Z10258582M6TRCEOCUBUW"]

    condition {
      test     = "ForAllValues:StringEquals"
      variable = "route53:ChangeResourceRecordSetsNormalizedRecordNames"
      values   = ["staging.needu.gift"]
    }

    condition {
      test     = "ForAllValues:StringEquals"
      variable = "route53:ChangeResourceRecordSetsRecordTypes"
      values   = ["CNAME"]
    }

    condition {
      test     = "ForAllValues:StringEquals"
      variable = "route53:ChangeResourceRecordSetsActions"
      values   = ["UPSERT"]
    }
  }

  # DNS 변경 완료 여부와 현재 레코드를 확인할 때 필요하다.
  statement {
    sid    = "ReadStagingCutoverStatus"
    effect = "Allow"

    actions = [
      "route53:GetChange",
      "route53:ListResourceRecordSets"
    ]

    resources = [
      "arn:aws:route53:::hostedzone/Z10258582M6TRCEOCUBUW",
      "arn:aws:route53:::change/*"
    ]
  }
}

resource "aws_iam_role_policy" "staging_control" {
  name   = "StagingPowerControl"
  role   = aws_iam_role.staging_control.id
  policy = data.aws_iam_policy_document.staging_control.json
}

output "staging_control_role_arn" {
  description = "Staging ECS, RDS, and ALB cutover control role for GitHub Actions"
  value       = aws_iam_role.staging_control.arn
}
