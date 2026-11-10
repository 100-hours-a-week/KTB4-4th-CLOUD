locals {
  prod_monitoring_role_arns = [
    "arn:aws:iam::${local.account_id}:role/${local.prod_prefix}-adot",
    "arn:aws:iam::${local.account_id}:role/${local.prod_prefix}-fluent-bit",
    "arn:aws:iam::${local.account_id}:role/${local.prod_prefix}-discord-notifier",
  ]
}

data "aws_iam_policy_document" "v3_prod_monitoring_iam" {
  statement {
    sid    = "ManageProdMonitoringRoles"
    effect = "Allow"
    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:DeleteRolePolicy",
      "iam:PutRolePolicy",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:UpdateAssumeRolePolicy",
    ]
    resources = local.prod_monitoring_role_arns
  }

  statement {
    sid     = "PassProdMonitoringRolesToEKS"
    effect  = "Allow"
    actions = ["iam:PassRole"]
    resources = [
      "arn:aws:iam::${local.account_id}:role/${local.prod_prefix}-adot",
      "arn:aws:iam::${local.account_id}:role/${local.prod_prefix}-fluent-bit",
    ]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["pods.eks.amazonaws.com"]
    }
  }

  statement {
    sid       = "PassProdDiscordNotifierRoleToLambda"
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = ["arn:aws:iam::${local.account_id}:role/${local.prod_prefix}-discord-notifier"]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "v3_prod_monitoring_iam" {
  name        = "NeedU-V3-Terraform-Prod-MonitoringIAM"
  description = "Allows V3 Production Terraform to manage monitoring workload roles"
  policy      = data.aws_iam_policy_document.v3_prod_monitoring_iam.json
}

resource "aws_iam_role_policy_attachment" "v3_prod_monitoring_iam" {
  role       = aws_iam_role.v3_prod_apply.name
  policy_arn = aws_iam_policy.v3_prod_monitoring_iam.arn
}

data "aws_iam_policy_document" "v3_prod_monitoring_resources" {
  statement {
    sid    = "CreateProdAMPWorkspace"
    effect = "Allow"
    actions = [
      "aps:CreateWorkspace",
      "aps:TagResource",
    ]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/Environment"
      values   = ["prod"]
    }
  }

  statement {
    sid    = "ManageProdAMPWorkspace"
    effect = "Allow"
    actions = [
      "aps:DeleteWorkspace",
      "aps:TagResource",
      "aps:UntagResource",
      "aps:UpdateWorkspaceAlias",
    ]
    resources = ["arn:aws:aps:${local.region}:${local.account_id}:workspace/*"]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/Environment"
      values   = ["prod"]
    }
  }

  statement {
    sid    = "ManageProdMonitoringLogGroups"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:DeleteLogGroup",
      "logs:DeleteRetentionPolicy",
      "logs:PutRetentionPolicy",
      "logs:TagResource",
      "logs:UntagResource",
    ]
    resources = [
      "arn:aws:logs:${local.region}:${local.account_id}:log-group:/needu/v3/prod/eks/application",
      "arn:aws:logs:${local.region}:${local.account_id}:log-group:/needu/v3/prod/eks/application:*",
      "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/lambda/needu-v3-prod-discord-notifier",
      "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/lambda/needu-v3-prod-discord-notifier:*",
    ]
  }
}

resource "aws_iam_policy" "v3_prod_monitoring_resources" {
  name        = "NeedU-V3-Terraform-Prod-MonitoringResources"
  description = "Allows V3 Production Terraform to manage AMP and monitoring log groups"
  policy      = data.aws_iam_policy_document.v3_prod_monitoring_resources.json
}

resource "aws_iam_role_policy_attachment" "v3_prod_monitoring_resources" {
  role       = aws_iam_role.v3_prod_apply.name
  policy_arn = aws_iam_policy.v3_prod_monitoring_resources.arn
}

data "aws_iam_policy_document" "v3_prod_alerting_resources" {
  statement {
    sid    = "ManageProdAlertTopic"
    effect = "Allow"
    actions = [
      "sns:CreateTopic",
      "sns:DeleteTopic",
      "sns:Subscribe",
      "sns:Unsubscribe",
      "sns:SetTopicAttributes",
      "sns:SetSubscriptionAttributes",
      "sns:TagResource",
      "sns:UntagResource",
    ]
    resources = ["arn:aws:sns:${local.region}:${local.account_id}:needu-v3-prod-alerts"]
  }

  statement {
    sid    = "ManageProdDiscordWebhookSecret"
    effect = "Allow"
    actions = [
      "secretsmanager:CreateSecret",
      "secretsmanager:DeleteSecret",
      "secretsmanager:RestoreSecret",
      "secretsmanager:TagResource",
      "secretsmanager:UntagResource",
      "secretsmanager:UpdateSecret",
    ]
    resources = ["arn:aws:secretsmanager:${local.region}:${local.account_id}:secret:needu/v3/prod/discord-webhook-*"]
  }

  statement {
    sid    = "ManageProdDiscordNotifier"
    effect = "Allow"
    actions = [
      "lambda:AddPermission",
      "lambda:CreateFunction",
      "lambda:DeleteFunction",
      "lambda:RemovePermission",
      "lambda:TagResource",
      "lambda:UntagResource",
      "lambda:UpdateFunctionCode",
      "lambda:UpdateFunctionConfiguration",
    ]
    resources = ["arn:aws:lambda:${local.region}:${local.account_id}:function:needu-v3-prod-discord-notifier"]
  }
}

resource "aws_iam_policy" "v3_prod_alerting_resources" {
  name        = "NeedU-V3-Terraform-Prod-AlertingResources"
  description = "Allows V3 Production Terraform to manage SNS and Discord notification resources"
  policy      = data.aws_iam_policy_document.v3_prod_alerting_resources.json
}

resource "aws_iam_role_policy_attachment" "v3_prod_alerting_resources" {
  role       = aws_iam_role.v3_prod_apply.name
  policy_arn = aws_iam_policy.v3_prod_alerting_resources.arn
}

data "aws_iam_policy_document" "v3_prod_amp_alerting" {
  statement {
    sid    = "ManageProdAMPAlertManager"
    effect = "Allow"
    actions = [
      "aps:CreateAlertManagerDefinition",
      "aps:DeleteAlertManagerDefinition",
      "aps:PutAlertManagerDefinition",
    ]
    resources = ["arn:aws:aps:${local.region}:${local.account_id}:workspace/*"]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/Environment"
      values   = ["prod"]
    }
  }

  statement {
    sid       = "CreateProdAMPRuleGroups"
    effect    = "Allow"
    actions   = ["aps:CreateRuleGroupsNamespace"]
    resources = ["arn:aws:aps:${local.region}:${local.account_id}:rulegroupsnamespace/*/needu-v3-prod-alert-rules"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/Environment"
      values   = ["prod"]
    }
  }

  statement {
    sid    = "UpdateProdAMPRuleGroups"
    effect = "Allow"
    actions = [
      "aps:DeleteRuleGroupsNamespace",
      "aps:PutRuleGroupsNamespace",
      "aps:UntagResource",
    ]
    resources = [
      "arn:aws:aps:${local.region}:${local.account_id}:rulegroupsnamespace/*/needu-v3-prod-alert-rules",
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/Environment"
      values   = ["prod"]
    }
  }

  statement {
    sid       = "TagProdAMPRuleGroups"
    effect    = "Allow"
    actions   = ["aps:TagResource"]
    resources = ["arn:aws:aps:${local.region}:${local.account_id}:rulegroupsnamespace/*/needu-v3-prod-alert-rules"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/Environment"
      values   = ["prod"]
    }
  }
}

resource "aws_iam_policy" "v3_prod_amp_alerting" {
  name        = "NeedU-V3-Terraform-Prod-AMPAlerting"
  description = "Allows V3 Production Terraform to manage AMP alert routing and rules"
  policy      = data.aws_iam_policy_document.v3_prod_amp_alerting.json
}

resource "aws_iam_role_policy_attachment" "v3_prod_amp_alerting" {
  role       = aws_iam_role.v3_prod_apply.name
  policy_arn = aws_iam_policy.v3_prod_amp_alerting.arn
}
