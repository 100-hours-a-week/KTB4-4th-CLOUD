# ==================================================
# NeedU V2 - Staging Migration Preflight Role
# ==================================================

locals {
  staging_migration_preflight_role_name = "NeedU-V2-Staging-Migration-Preflight"
  shared_ssm_bastion_instance_id        = "i-0fc4a029b4d5b90ca"
}

data "aws_db_instance" "staging_preflight_mysql" {
  db_instance_identifier = "needu-staging-mysql"
}

data "aws_db_instance" "staging_preflight_postgres" {
  db_instance_identifier = "needu-staging-postgres"
}

data "aws_iam_policy_document" "staging_migration_preflight_trust" {
  statement {
    sid     = "GitHubStagingEnvironmentOnly"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github_actions_terraform.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:100-hours-a-week@167328634/KTB4-4th-CLOUD@1344657749:environment:staging"]
    }
  }
}

resource "aws_iam_role" "staging_migration_preflight" {
  name               = local.staging_migration_preflight_role_name
  assume_role_policy = data.aws_iam_policy_document.staging_migration_preflight_trust.json
  tags = {
    Project     = "NeedU"
    ManagedBy   = "Terraform"
    Purpose     = "StagingMigrationPreflight"
    Environment = "staging"
  }
}

data "aws_iam_policy_document" "staging_migration_preflight" {
  statement {
    sid    = "ReadStagingMigrationResources"
    effect = "Allow"
    actions = [
      "dms:DescribeConnections",
      "dms:DescribeReplicationTasks",
      "dms:DescribeTableStatistics",
      "ecs:DescribeServices",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeRules",
      "elasticloadbalancing:DescribeTags",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:DescribeTargetHealth",
      "rds:DescribeDBInstances",
      "ssm:DescribeInstanceInformation"
    ]
    resources = ["*"]
  }

  statement {
    sid     = "StartStagingDatabaseTunnel"
    effect  = "Allow"
    actions = ["ssm:StartSession"]
    resources = [
      "arn:aws:ec2:ap-northeast-2:${data.aws_caller_identity.current.account_id}:instance/${local.shared_ssm_bastion_instance_id}",
      "arn:aws:ssm:ap-northeast-2::document/AWS-StartPortForwardingSessionToRemoteHost"
    ]
  }

  statement {
    sid       = "CloseOwnDatabaseTunnel"
    effect    = "Allow"
    actions   = ["ssm:TerminateSession"]
    resources = ["arn:aws:ssm:ap-northeast-2:${data.aws_caller_identity.current.account_id}:session/$${aws:userid}-*"]
  }

  statement {
    sid     = "ReadStagingDatabaseSecrets"
    effect  = "Allow"
    actions = ["secretsmanager:GetSecretValue"]
    resources = [
      data.aws_db_instance.staging_preflight_mysql.master_user_secret[0].secret_arn,
      data.aws_db_instance.staging_preflight_postgres.master_user_secret[0].secret_arn
    ]
  }
}

resource "aws_iam_role_policy" "staging_migration_preflight" {
  name   = "StagingMigrationPreflight"
  role   = aws_iam_role.staging_migration_preflight.id
  policy = data.aws_iam_policy_document.staging_migration_preflight.json
}

output "staging_migration_preflight_role_arn" {
  description = "Read-only GitHub Actions role for Staging migration preflight"
  value       = aws_iam_role.staging_migration_preflight.arn
}
