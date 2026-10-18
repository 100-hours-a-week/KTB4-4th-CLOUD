locals {
  prod_migration_preflight_role_name = "NeedU-V2-Prod-Migration-Preflight"
  prod_migration_oidc_provider_arn   = "arn:aws:iam::919551759796:oidc-provider/token.actions.githubusercontent.com"
}

resource "aws_iam_role" "prod_migration_preflight" {
  name = local.prod_migration_preflight_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "GitHubProdMigrationEnvironmentOnly"
        Effect = "Allow"

        Principal = {
          Federated = local.prod_migration_oidc_provider_arn
        }

        Action = "sts:AssumeRoleWithWebIdentity"

        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            "token.actions.githubusercontent.com:sub" = "repo:100-hours-a-week@167328634/KTB4-4th-CLOUD@1344657749:environment:prod-migration"
          }
        }
      }
    ]
  })

  tags = {
    Project     = "NeedU"
    Environment = "prod"
    Purpose     = "ProdMigrationPreflight"
  }
}

resource "aws_iam_role_policy" "prod_migration_preflight" {
  name = "ProdMigrationPreflightReadOnly"
  role = aws_iam_role.prod_migration_preflight.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadProdMigrationResources"
        Effect = "Allow"

        Action = [
          "sts:GetCallerIdentity",

          "ecs:DescribeServices",

          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:DescribeRules",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeTargetHealth",
          "elasticloadbalancing:DescribeTags",

          "dms:DescribeReplicationTasks",
          "dms:DescribeTableStatistics",
          "dms:DescribeConnections",

          "rds:DescribeDBInstances",

          "ec2:DescribeAddresses",

          "ssm:DescribeInstanceInformation",

          "route53:ListHostedZones",
          "route53:ListHostedZonesByName",
          "route53:ListResourceRecordSets",
          "route53:GetHostedZone",
          "route53:GetChange"
        ]

        Resource = "*"
      },
      {
        Sid      = "ReadProdRDSManagedSecrets"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = "arn:aws:secretsmanager:ap-northeast-2:919551759796:secret:rds!db-*"
      },
      {
        Sid    = "OpenProdDatabaseTunnels"
        Effect = "Allow"
        Action = ["ssm:StartSession"]
        Resource = [
          "arn:aws:ec2:ap-northeast-2:919551759796:instance/i-0fc4a029b4d5b90ca",
          "arn:aws:ssm:ap-northeast-2::document/AWS-StartPortForwardingSessionToRemoteHost"
        ]
      },
      {
        Sid      = "CloseOwnDatabaseTunnels"
        Effect   = "Allow"
        Action   = ["ssm:TerminateSession"]
        Resource = "arn:aws:ssm:*:919551759796:session/*"
      }
    ]
  })
}

output "prod_migration_preflight_role_arn" {
  value = aws_iam_role.prod_migration_preflight.arn
}
