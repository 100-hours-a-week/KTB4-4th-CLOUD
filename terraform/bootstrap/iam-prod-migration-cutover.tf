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

          "dms:DescribeReplicationTasks",
          "dms:DescribeTableStatistics",
          "dms:DescribeReplicationInstances",

          "rds:DescribeDBInstances",

          "ssm:DescribeInstanceInformation",

          "route53:ListHostedZones",
          "route53:ListResourceRecordSets",
          "route53:GetHostedZone",
          "route53:GetChange"
        ]

        Resource = "*"
      }
    ]
  })
}

output "prod_migration_cutover_role_arn" {
  value = aws_iam_role.prod_migration_cutover.arn
}