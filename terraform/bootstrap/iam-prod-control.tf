locals {
  prod_control_role_name = "NeedU-V2-Prod-Control"
}

data "aws_iam_policy_document" "prod_control_github_trust" {
  statement {
    sid     = "GitHubProdEnvironmentOnly"
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
      values   = ["repo:100-hours-a-week@167328634/KTB4-4th-CLOUD@1344657749:environment:prod"]
    }
  }
}

resource "aws_iam_role" "prod_control" {
  name               = local.prod_control_role_name
  assume_role_policy = data.aws_iam_policy_document.prod_control_github_trust.json

  tags = {
    Project     = "NeedU"
    ManagedBy   = "Terraform"
    Purpose     = "ProdMigrationControl"
    Environment = "prod"
  }
}

data "aws_iam_policy_document" "prod_control" {
  statement {
    sid    = "ManageProdECSServices"
    effect = "Allow"

    actions = [
      "ecs:DescribeServices",
      "ecs:UpdateService"
    ]

    resources = [
      "arn:aws:ecs:ap-northeast-2:${data.aws_caller_identity.current.account_id}:service/needu-prod-cluster/needu-prod-frontend",
      "arn:aws:ecs:ap-northeast-2:${data.aws_caller_identity.current.account_id}:service/needu-prod-cluster/needu-prod-backend",
      "arn:aws:ecs:ap-northeast-2:${data.aws_caller_identity.current.account_id}:service/needu-prod-cluster/needu-prod-ai"
    ]
  }

  statement {
    sid    = "ManageProdECSScaling"
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
      values   = ["prod"]
    }
  }

  statement {
    sid       = "ReadProdECSScalingStatus"
    effect    = "Allow"
    actions   = ["application-autoscaling:DescribeScalableTargets"]
    resources = ["*"]
  }

  statement {
    sid    = "ReadProdLoadBalancerStatus"
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

  statement {
    sid    = "ManageProdALBCutoverRules"
    effect = "Allow"

    actions = [
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:CreateRule",
      "elasticloadbalancing:DeleteRule",
      "elasticloadbalancing:ModifyRule"
    ]

    resources = [
      "arn:aws:elasticloadbalancing:ap-northeast-2:${data.aws_caller_identity.current.account_id}:listener/app/needu-prod-alb/*/*",
      "arn:aws:elasticloadbalancing:ap-northeast-2:${data.aws_caller_identity.current.account_id}:listener-rule/app/needu-prod-alb/*/*/*"
    ]
  }
}

resource "aws_iam_role_policy" "prod_control" {
  name   = "ProdMigrationControl"
  role   = aws_iam_role.prod_control.id
  policy = data.aws_iam_policy_document.prod_control.json
}

output "prod_control_role_arn" {
  description = "Prod ECS Runtime, ALB Write Gate와 Cutover를 제어하는 GitHub Actions Role"
  value       = aws_iam_role.prod_control.arn
}
