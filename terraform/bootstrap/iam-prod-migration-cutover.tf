resource "aws_iam_role" "prod_migration_cutover" {
  name = "NeedU-V2-Prod-Migration-Cutover"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "GitHubProdMigrationCutoverEnvironmentOnly"
        Effect = "Allow"

        Principal = {
          Federated = local.prod_migration_oidc_provider_arn
        }

        Action = "sts:AssumeRoleWithWebIdentity"

        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            "token.actions.githubusercontent.com:sub" = "repo:100-hours-a-week@167328634/KTB4-4th-CLOUD@1344657749:environment:prod-migration-cutover"
          }
        }
      }
    ]
  })

  tags = {
    Project     = "NeedU"
    Environment = "prod"
    Purpose     = "ProdMigrationCutover"
  }
}

resource "aws_iam_role_policy" "prod_migration_cutover" {
  name = "ProdMigrationCutoverReadOnly"
  role = aws_iam_role.prod_migration_cutover.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadProdCutoverResources"
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
          "dms:DescribeReplicationInstances",

          "rds:DescribeDBInstances",

          "ec2:DescribeAddresses",

          "cloudwatch:GetMetricStatistics",

          "ssm:DescribeInstanceInformation",

          "route53:ListHostedZones",
          "route53:ListResourceRecordSets",
          "route53:GetHostedZone",
          "route53:GetChange"
        ]

        Resource = "*"
      },
      {
        Sid    = "ControlProdALBRules"
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:CreateRule",
          "elasticloadbalancing:DeleteRule",
          "elasticloadbalancing:ModifyRule",
          "elasticloadbalancing:AddTags"
        ]
        Resource = [
          "arn:aws:elasticloadbalancing:ap-northeast-2:919551759796:listener/app/needu-prod-alb/*",
          "arn:aws:elasticloadbalancing:ap-northeast-2:919551759796:listener-rule/app/needu-prod-alb/*"
        ]
      },
      {
        Sid      = "StopProdDMSTask"
        Effect   = "Allow"
        Action   = ["dms:StopReplicationTask"]
        Resource = "arn:aws:dms:ap-northeast-2:919551759796:task:V7E7JE6J2FHVJPKNYDO7L7RTGE"
      },
      {
        Sid      = "ChangeProdDNS"
        Effect   = "Allow"
        Action   = ["route53:ChangeResourceRecordSets"]
        Resource = "arn:aws:route53:::hostedzone/Z10258582M6TRCEOCUBUW"
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
        Sid    = "CheckV1OpenTransactions"
        Effect = "Allow"
        Action = ["ssm:SendCommand"]
        Resource = [
          "arn:aws:ec2:ap-northeast-2:919551759796:instance/i-071de18816cfae436",
          "arn:aws:ssm:ap-northeast-2::document/AWS-RunShellScript"
        ]
      },
      {
        Sid      = "ReadV1TransactionCheck"
        Effect   = "Allow"
        Action   = ["ssm:GetCommandInvocation"]
        Resource = "*"
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

output "prod_migration_cutover_role_arn" {
  value = aws_iam_role.prod_migration_cutover.arn
}
