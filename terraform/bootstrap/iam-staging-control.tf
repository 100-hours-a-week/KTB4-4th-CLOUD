# ==================================================
# NeedU V2 - Staging Control Role
#
# GitHub Actions Staging Environment 전용
#
# 기존 기능:
# - Staging ECS 시작/정지
# - Staging RDS 시작/정지
# - Staging ALB Listener Rule 변경
# - Staging DNS 변경
#
# Migration Cutover 추가:
# - DMS Task 상태/Validation 조회 및 중지
# - CloudWatch CDC 지연 지표 조회
# - V1 EC2 트랜잭션 확인 (SSM Run Command)
# - SSM Bastion을 통한 V2 MySQL 터널
# - Staging MySQL Secret 조회
#
# Terraform Apply Role과 분리
# ==================================================

locals {
  staging_control_role_name = "NeedU-V2-Staging-Control"

  staging_dms_task_arn = "arn:aws:dms:ap-northeast-2:${data.aws_caller_identity.current.account_id}:task:BQMH5JA3RNCDNGPD2DWZA3VZJU"

  staging_v1_instance_id      = "i-0576742bcb4121640"
  staging_bastion_instance_id = "i-0fc4a029b4d5b90ca"
}

# ==================================================
# GitHub OIDC Trust
# ==================================================

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

# ==================================================
# IAM Role
# ==================================================

resource "aws_iam_role" "staging_control" {
  name = local.staging_control_role_name

  assume_role_policy = data.aws_iam_policy_document.staging_control_github_trust.json

  tags = {
    Project     = "NeedU"
    ManagedBy   = "Terraform"
    Purpose     = "StagingPowerAndMigrationControl"
    Environment = "staging"
  }
}

# ==================================================
# Staging MySQL RDS Secret
# ==================================================

data "aws_db_instance" "staging_control_mysql" {
  db_instance_identifier = "needu-staging-mysql"
}

# ==================================================
# IAM Policy
# ==================================================

data "aws_iam_policy_document" "staging_control" {

  # ------------------------------------------------
  # ECS Service Control
  # ------------------------------------------------

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

  # ------------------------------------------------
  # ECS Auto Scaling
  # ------------------------------------------------

  statement {
    sid    = "ManageStagingECSScaling"
    effect = "Allow"

    actions = [
      "application-autoscaling:RegisterScalableTarget"
    ]

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

  statement {
    sid    = "ReadECSScalingStatus"
    effect = "Allow"

    actions = [
      "application-autoscaling:DescribeScalableTargets"
    ]

    resources = ["*"]
  }

  # ------------------------------------------------
  # RDS Control
  # ------------------------------------------------

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

  statement {
    sid    = "ReadStagingDatabaseStatus"
    effect = "Allow"

    actions = [
      "rds:DescribeDBInstances"
    ]

    resources = ["*"]
  }

  # ------------------------------------------------
  # ALB Read
  # ------------------------------------------------

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

  # ------------------------------------------------
  # ALB Cutover
  # ------------------------------------------------

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

  # ------------------------------------------------
  # Route 53 Cutover
  # ------------------------------------------------

  statement {
    sid    = "ChangeStagingCutoverRecord"
    effect = "Allow"

    actions = [
      "route53:ChangeResourceRecordSets"
    ]

    resources = [
      "arn:aws:route53:::hostedzone/Z10258582M6TRCEOCUBUW"
    ]

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

  # ==================================================
  # Migration Cutover Permissions
  # ==================================================

  # ------------------------------------------------
  # DMS Task Read
  # ------------------------------------------------

  statement {
    sid    = "ReadStagingMigrationDMS"
    effect = "Allow"

    actions = [
      "dms:DescribeReplicationTasks",
      "dms:DescribeTableStatistics"
    ]

    resources = ["*"]
  }

  # ------------------------------------------------
  # DMS Task Stop
  # ------------------------------------------------

  statement {
    sid    = "StopStagingMigrationDMS"
    effect = "Allow"

    actions = [
      "dms:StopReplicationTask"
    ]

    resources = [
      local.staging_dms_task_arn
    ]
  }

  # ------------------------------------------------
  # CloudWatch CDC Metrics
  # ------------------------------------------------

  statement {
    sid    = "ReadStagingDMSMetrics"
    effect = "Allow"

    actions = [
      "cloudwatch:GetMetricStatistics"
    ]

    resources = ["*"]
  }

  # ------------------------------------------------
  # V1 EC2 Transaction Check
  # ------------------------------------------------

  statement {
    sid    = "SendV1TransactionCheckCommand"
    effect = "Allow"

    actions = [
      "ssm:SendCommand"
    ]

    resources = [
      "arn:aws:ec2:ap-northeast-2:${data.aws_caller_identity.current.account_id}:instance/${local.staging_v1_instance_id}",
      "arn:aws:ssm:ap-northeast-2::document/AWS-RunShellScript"
    ]
  }

  statement {
    sid    = "ReadV1TransactionCheckResult"
    effect = "Allow"

    actions = [
      "ssm:GetCommandInvocation",
      "ssm:ListCommandInvocations"
    ]

    resources = ["*"]
  }

  # ------------------------------------------------
  # SSM Bastion DB Tunnel
  # ------------------------------------------------

  statement {
    sid    = "StartStagingDBTunnel"
    effect = "Allow"

    actions = [
      "ssm:StartSession"
    ]

    resources = [
      "arn:aws:ec2:ap-northeast-2:${data.aws_caller_identity.current.account_id}:instance/${local.staging_bastion_instance_id}",
      "arn:aws:ssm:ap-northeast-2::document/AWS-StartPortForwardingSessionToRemoteHost"
    ]
  }

  statement {
    sid    = "TerminateStagingDBTunnel"
    effect = "Allow"

    actions = [
      "ssm:TerminateSession"
    ]

    resources = [
      "arn:aws:ssm:ap-northeast-2:${data.aws_caller_identity.current.account_id}:session/*"
    ]
  }

  # ------------------------------------------------
  # Staging MySQL Secret
  # ------------------------------------------------

  statement {
    sid    = "ReadStagingMySQLSecret"
    effect = "Allow"

    actions = [
      "secretsmanager:GetSecretValue"
    ]

    resources = [
      data.aws_db_instance.staging_control_mysql.master_user_secret[0].secret_arn
    ]
  }
}

# ==================================================
# Attach IAM Policy
# ==================================================

resource "aws_iam_role_policy" "staging_control" {
  name = "StagingPowerControl"

  role = aws_iam_role.staging_control.id

  policy = data.aws_iam_policy_document.staging_control.json
}

# ==================================================
# Outputs
# ==================================================

output "staging_control_role_arn" {
  description = "Staging ECS, RDS, ALB and migration cutover control role for GitHub Actions"

  value = aws_iam_role.staging_control.arn
}