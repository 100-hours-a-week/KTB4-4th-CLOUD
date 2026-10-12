# ==================================================
# NeedU V2 - Terraform Apply IAM Policies
# ==================================================

locals {
  terraform_environments = toset([
    "dev",
    "staging",
    "prod"
  ])

  terraform_shared_apply_actions = [
    "ec2:CreateVpc",
    "ec2:ModifyVpcAttribute",
    "ec2:DeleteVpc",
    "ec2:CreateInternetGateway",
    "ec2:AttachInternetGateway",
    "ec2:DetachInternetGateway",
    "ec2:DeleteInternetGateway",
    "ec2:CreateTags",
    "ec2:DeleteTags",

    "ecr:CreateRepository",
    "ecr:DeleteRepository",
    "ecr:PutImageTagMutability",
    "ecr:PutImageScanningConfiguration",
    "ecr:TagResource",
    "ecr:UntagResource"
  ]

  terraform_environment_apply_actions = [
    "ec2:CreateSubnet",
    "ec2:DeleteSubnet",
    "ec2:ModifySubnetAttribute",
    "ec2:CreateRouteTable",
    "ec2:DeleteRouteTable",
    "ec2:CreateRoute",
    "ec2:DeleteRoute",
    "ec2:AssociateRouteTable",
    "ec2:DisassociateRouteTable",
    "ec2:CreateSecurityGroup",
    "ec2:DeleteSecurityGroup",
    "ec2:AuthorizeSecurityGroupIngress",
    "ec2:AuthorizeSecurityGroupEgress",
    "ec2:RevokeSecurityGroupIngress",
    "ec2:RevokeSecurityGroupEgress",
    "ec2:CreateSecurityGroupRule",
    "ec2:ModifySecurityGroupRules",
    "ec2:CreateTags",
    "ec2:DeleteTags",

    "elasticloadbalancing:CreateLoadBalancer",
    "elasticloadbalancing:ModifyLoadBalancerAttributes",
    "elasticloadbalancing:DeleteLoadBalancer",
    "elasticloadbalancing:CreateTargetGroup",
    "elasticloadbalancing:ModifyTargetGroup",
    "elasticloadbalancing:DeleteTargetGroup",
    "elasticloadbalancing:CreateListener",
    "elasticloadbalancing:ModifyListener",
    "elasticloadbalancing:DeleteListener",
    "elasticloadbalancing:CreateRule",
    "elasticloadbalancing:ModifyRule",
    "elasticloadbalancing:DeleteRule",
    "elasticloadbalancing:AddTags",
    "elasticloadbalancing:RemoveTags",

    "application-autoscaling:RegisterScalableTarget",
    "application-autoscaling:DeregisterScalableTarget",
    "application-autoscaling:PutScalingPolicy",
    "application-autoscaling:DeleteScalingPolicy",
    "application-autoscaling:TagResource",
    "application-autoscaling:UntagResource",

    "logs:CreateLogGroup",
    "logs:DeleteLogGroup",
    "logs:PutRetentionPolicy",
    "logs:TagResource",
    "logs:UntagResource",

    "cloudwatch:PutMetricAlarm",
    "cloudwatch:DeleteAlarms",

    "elasticache:CreateReplicationGroup",
    "elasticache:ModifyReplicationGroup",
    "elasticache:DeleteReplicationGroup",
    "elasticache:CreateCacheSubnetGroup",
    "elasticache:ModifyCacheSubnetGroup",
    "elasticache:DeleteCacheSubnetGroup",
    "elasticache:AddTagsToResource",
    "elasticache:RemoveTagsFromResource",

    "servicediscovery:CreateHttpNamespace",
    "servicediscovery:DeleteNamespace"
  ]
}

# ==================================================
# 1. Shared Infrastructure Apply
# ==================================================

data "aws_iam_policy_document" "terraform_shared_apply" {
  statement {
    sid       = "ManageSharedResources"
    effect    = "Allow"
    actions   = local.terraform_shared_apply_actions
    resources = ["*"]
  }

  # Shared ACM 인증서 생성 및 관리
  statement {
    sid    = "ManageSharedACMCertificates"
    effect = "Allow"

    actions = [
      "acm:RequestCertificate",
      "acm:DeleteCertificate",
      "acm:AddTagsToCertificate",
      "acm:RemoveTagsFromCertificate",
      "acm:UpdateCertificateOptions"
    ]

    resources = [
      "arn:aws:acm:ap-northeast-2:${data.aws_caller_identity.current.account_id}:certificate/*"
    ]
  }

  # Shared에서 환경별 ACM 인증서 ARN을 SSM에 저장
  statement {
    sid    = "ManageSharedACMCertificateParameters"
    effect = "Allow"

    actions = [
      "ssm:PutParameter",
      "ssm:DeleteParameter",
      "ssm:AddTagsToResource",
      "ssm:RemoveTagsFromResource"
    ]

    resources = [
      for env in local.terraform_environments :
      "arn:aws:ssm:ap-northeast-2:${data.aws_caller_identity.current.account_id}:parameter/needu/v2/${env}/acm/certificate-arn"
    ]
  }

  # Shared ACM DNS 검증 레코드 관리
  statement {
    sid    = "ManageSharedACMValidationRecords"
    effect = "Allow"

    actions = [
      "route53:ChangeResourceRecordSets"
    ]

    resources = [
      "arn:aws:route53:::hostedzone/*"
    ]
  }

  # DNS 변경 완료 여부 확인
  statement {
    sid    = "CheckSharedDNSChanges"
    effect = "Allow"

    actions = [
      "route53:GetChange"
    ]

    resources = [
      "arn:aws:route53:::change/*"
    ]
  }
}

resource "aws_iam_role_policy" "terraform_shared_apply" {
  name   = "TerraformSharedApply"
  role   = aws_iam_role.terraform_github["shared"].id
  policy = data.aws_iam_policy_document.terraform_shared_apply.json
}

# ==================================================
# 2. Environment Infrastructure Apply
# ==================================================

data "aws_iam_policy_document" "terraform_environment_apply" {
  for_each = local.terraform_environments

  statement {
    sid       = "ManageEnvironmentInfrastructure"
    effect    = "Allow"
    actions   = local.terraform_environment_apply_actions
    resources = ["*"]
  }

  # Catalog S3 Bucket 생성 및 설정
  statement {
    sid    = "ManageEnvironmentCatalogBuckets"
    effect = "Allow"

    actions = [
      "s3:CreateBucket",
      "s3:DeleteBucket",
      "s3:PutBucketVersioning",
      "s3:PutEncryptionConfiguration",
      "s3:PutBucketPublicAccessBlock",
      "s3:PutBucketTagging",
      "s3:DeleteBucketTagging"
    ]

    resources = [
      "arn:aws:s3:::needu-${each.key}-catalog-*"
    ]
  }

  # Catalog S3 객체 조회 및 삭제
  statement {
    sid    = "ManageEnvironmentCatalogObjects"
    effect = "Allow"

    actions = [
      "s3:ListBucket",
      "s3:ListBucketVersions",
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:DeleteObject",
      "s3:DeleteObjectVersion"
    ]

    resources = [
      "arn:aws:s3:::needu-${each.key}-catalog-*",
      "arn:aws:s3:::needu-${each.key}-catalog-*/*"
    ]
  }

  # 환경별 Route 53 DNS 레코드 관리
  statement {
    sid    = "ManageEnvironmentDNSRecords"
    effect = "Allow"

    actions = [
      "route53:ChangeResourceRecordSets"
    ]

    resources = [
      "arn:aws:route53:::hostedzone/*"
    ]
  }

  # Route 53 DNS 변경 상태 조회
  statement {
    sid    = "CheckDNSChanges"
    effect = "Allow"

    actions = [
      "route53:GetChange"
    ]

    resources = [
      "arn:aws:route53:::change/*"
    ]
  }

  # 환경별 SSM Parameter 생성 및 관리
  statement {
    sid    = "ManageEnvironmentSSMParameters"
    effect = "Allow"

    actions = [
      "ssm:PutParameter",
      "ssm:DeleteParameter",
      "ssm:DeleteParameters",
      "ssm:AddTagsToResource",
      "ssm:RemoveTagsFromResource"
    ]

    resources = [
      "arn:aws:ssm:ap-northeast-2:${data.aws_caller_identity.current.account_id}:parameter/needu/v2/${each.key}/*"
    ]
  }
}

resource "aws_iam_role_policy" "terraform_environment_apply" {
  for_each = local.terraform_environments

  name   = "TerraformEnvironmentApply"
  role   = aws_iam_role.terraform_github[each.key].id
  policy = data.aws_iam_policy_document.terraform_environment_apply[each.key].json
}

# ==================================================
# 3. Environment ECS Apply
# ==================================================

data "aws_iam_policy_document" "terraform_ecs_apply" {
  for_each = local.terraform_environments

  statement {
    sid    = "ManageEnvironmentECS"
    effect = "Allow"

    actions = [
      "ecs:CreateCluster",
      "ecs:DeleteCluster",
      "ecs:CreateService",
      "ecs:UpdateService",
      "ecs:DeleteService"
    ]

    resources = [
      "arn:aws:ecs:ap-northeast-2:${data.aws_caller_identity.current.account_id}:cluster/needu-${each.key}-*",
      "arn:aws:ecs:ap-northeast-2:${data.aws_caller_identity.current.account_id}:service/*/needu-${each.key}-*"
    ]
  }

  statement {
    sid       = "RegisterEnvironmentTaskDefinitions"
    effect    = "Allow"
    actions   = ["ecs:RegisterTaskDefinition"]
    resources = ["*"]
  }

  statement {
    sid     = "DeregisterEnvironmentTaskDefinitions"
    effect  = "Allow"
    actions = ["ecs:DeregisterTaskDefinition"]

    resources = [
      "arn:aws:ecs:ap-northeast-2:${data.aws_caller_identity.current.account_id}:task-definition/needu-${each.key}-*"
    ]
  }

  statement {
    sid     = "TagEnvironmentTaskDefinitions"
    effect  = "Allow"
    actions = ["ecs:TagResource"]

    resources = [
      "arn:aws:ecs:ap-northeast-2:${data.aws_caller_identity.current.account_id}:task-definition/needu-${each.key}-*"
    ]

    condition {
      test     = "StringEquals"
      variable = "ecs:CreateAction"
      values   = ["RegisterTaskDefinition"]
    }
  }

  # ECS Cluster 및 Service 생성 시 Provider default_tags 적용
  statement {
    sid     = "TagEnvironmentECSResources"
    effect  = "Allow"
    actions = ["ecs:TagResource"]

    resources = [
      "arn:aws:ecs:ap-northeast-2:${data.aws_caller_identity.current.account_id}:cluster/needu-${each.key}-*",
      "arn:aws:ecs:ap-northeast-2:${data.aws_caller_identity.current.account_id}:service/*/needu-${each.key}-*"
    ]

    condition {
      test     = "StringEquals"
      variable = "ecs:CreateAction"
      values   = ["CreateCluster", "CreateService"]
    }
  }
}

resource "aws_iam_role_policy" "terraform_ecs_apply" {
  for_each = local.terraform_environments

  name   = "TerraformECSApply"
  role   = aws_iam_role.terraform_github[each.key].id
  policy = data.aws_iam_policy_document.terraform_ecs_apply[each.key].json
}

# ==================================================
# 4. Environment IAM
# ==================================================

data "aws_iam_policy_document" "terraform_environment_iam" {
  for_each = local.terraform_environments

  # Runtime Permissions Boundary 필수
  statement {
    sid    = "CreateRuntimeRolesWithBoundary"
    effect = "Allow"

    actions = [
      "iam:CreateRole"
    ]

    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/needu-${each.key}-*-execution",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/needu-${each.key}-*-task"
    ]

    condition {
      test     = "ArnEquals"
      variable = "iam:PermissionsBoundary"

      values = [
        aws_iam_policy.runtime_boundary[each.key].arn
      ]
    }
  }

  # CD Permissions Boundary 필수
  statement {
    sid    = "CreateCDRoleWithBoundary"
    effect = "Allow"

    actions = [
      "iam:CreateRole"
    ]

    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/needu-${each.key}-*-github-ecs-cd"
    ]

    condition {
      test     = "ArnEquals"
      variable = "iam:PermissionsBoundary"

      values = [
        aws_iam_policy.cd_boundary[each.key].arn
      ]
    }
  }

  statement {
    sid    = "ManageEnvironmentIAMRoles"
    effect = "Allow"

    actions = [
      "iam:DeleteRole",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:DetachRolePolicy"
    ]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/needu-${each.key}-*-execution",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/needu-${each.key}-*-task",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/needu-${each.key}-*-github-ecs-cd"
    ]
  }

  # Permissions Boundary 변경 및 제거 금지
  statement {
    sid    = "DenyBoundaryModification"
    effect = "Deny"

    actions = [
      "iam:DeleteRolePermissionsBoundary",
      "iam:PutRolePermissionsBoundary"
    ]

    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/needu-${each.key}-*"
    ]
  }

  statement {
    sid    = "AttachECSTaskExecutionPolicy"
    effect = "Allow"

    actions = [
      "iam:AttachRolePolicy"
    ]

    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/needu-${each.key}-*-execution"
    ]

    condition {
      test     = "ArnEquals"
      variable = "iam:PolicyARN"

      values = [
        "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
      ]
    }
  }

  statement {
    sid    = "PassEnvironmentRolesToECS"
    effect = "Allow"

    actions = [
      "iam:PassRole"
    ]

    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/needu-${each.key}-*-execution",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/needu-${each.key}-*-task"
    ]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"

      values = [
        "ecs-tasks.amazonaws.com"
      ]
    }
  }
}

resource "aws_iam_role_policy" "terraform_environment_iam" {
  for_each = local.terraform_environments

  name   = "TerraformEnvironmentIAM"
  role   = aws_iam_role.terraform_github[each.key].id
  policy = data.aws_iam_policy_document.terraform_environment_iam[each.key].json
}

# ==================================================
# 5. Shared GitHub CI IAM
# ==================================================

data "aws_iam_policy_document" "terraform_shared_iam" {
  statement {
    sid    = "ManageSharedCIRoles"
    effect = "Allow"

    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:DetachRolePolicy"
    ]

    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/NeedU-V2-GitHubActions-CI",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/NeedU-V2-GitHubActions-CI-Frontend"
    ]
  }

  statement {
    sid    = "AttachApprovedSharedCIPolicies"
    effect = "Allow"

    actions = [
      "iam:AttachRolePolicy"
    ]

    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/NeedU-V2-GitHubActions-CI",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/NeedU-V2-GitHubActions-CI-Frontend"
    ]

    condition {
      test     = "ArnEquals"
      variable = "iam:PolicyARN"

      values = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/NeedU-V2-ECR-Push",
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/NeedU-V2-Frontend-ECR-Push",
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/NeedU-V2-Frontend-Build-SSM-Read"
      ]
    }
  }

  statement {
    sid    = "ManageSharedCIPolicies"
    effect = "Allow"

    actions = [
      "iam:CreatePolicy",
      "iam:DeletePolicy",
      "iam:CreatePolicyVersion",
      "iam:DeletePolicyVersion",
      "iam:SetDefaultPolicyVersion",
      "iam:TagPolicy",
      "iam:UntagPolicy"
    ]

    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/NeedU-V2-ECR-Push",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/NeedU-V2-Frontend-ECR-Push",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/NeedU-V2-Frontend-Build-SSM-Read"
    ]
  }
}

resource "aws_iam_role_policy" "terraform_shared_iam" {
  name   = "TerraformSharedIAM"
  role   = aws_iam_role.terraform_github["shared"].id
  policy = data.aws_iam_policy_document.terraform_shared_iam.json
}

# ==================================================
# 6. Environment RDS
# ==================================================

data "aws_iam_policy_document" "terraform_environment_rds" {
  for_each = local.terraform_environments

  statement {
    sid    = "ManageEnvironmentRDS"
    effect = "Allow"

    actions = [
      "rds:CreateDBInstance",
      "rds:ModifyDBInstance",
      "rds:DeleteDBInstance",
      "rds:CreateDBSubnetGroup",
      "rds:ModifyDBSubnetGroup",
      "rds:DeleteDBSubnetGroup",
      "rds:AddTagsToResource",
      "rds:RemoveTagsFromResource"
    ]

    resources = [
      "arn:aws:rds:ap-northeast-2:${data.aws_caller_identity.current.account_id}:db:needu-${each.key}-*",
      "arn:aws:rds:ap-northeast-2:${data.aws_caller_identity.current.account_id}:subgrp:needu-${each.key}-*",
      "arn:aws:rds:ap-northeast-2:${data.aws_caller_identity.current.account_id}:pg:needu-${each.key}-*"
    ]
  }

  # RDS 관리형 Master Password Secret
  statement {
    sid    = "ManageRDSManagedSecrets"
    effect = "Allow"

    actions = [
      "secretsmanager:CreateSecret",
      "secretsmanager:TagResource",
      "secretsmanager:UntagResource"
    ]

    resources = [
      "arn:aws:secretsmanager:ap-northeast-2:${data.aws_caller_identity.current.account_id}:secret:rds!*"
    ]
  }

  # RDS 관리형 Secret의 KMS 키 조회
  statement {
    sid    = "DescribeRDSKMSKeys"
    effect = "Allow"

    actions = [
      "kms:DescribeKey"
    ]

    resources = [
      "arn:aws:kms:ap-northeast-2:${data.aws_caller_identity.current.account_id}:key/*"
    ]
  }
}

resource "aws_iam_role_policy" "terraform_environment_rds" {
  for_each = local.terraform_environments

  name   = "TerraformEnvironmentRDS"
  role   = aws_iam_role.terraform_github[each.key].id
  policy = data.aws_iam_policy_document.terraform_environment_rds[each.key].json
}
