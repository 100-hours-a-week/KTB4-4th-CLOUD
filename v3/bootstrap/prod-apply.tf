
# v3/bootstrap/prod-apply.tf

locals {
  prod_role_name = "NeedU-V3-Terraform-Prod"
  prod_prefix    = "needu-v3-prod"
  account_id     = "919551759796"
  region         = "ap-northeast-2"
}

data "aws_iam_policy_document" "prod_trust" {
  statement {
    sid     = "ApprovedSSOAdmin"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::919551759796:root"]
    }

    condition {
      test     = "ArnEquals"
      variable = "aws:PrincipalArn"
      values = [
        "arn:aws:iam::919551759796:role/aws-reserved/sso.amazonaws.com/ap-northeast-2/AWSReservedSSO_NeedU-Terraform-Bootstrap-Admin_39de7a047c7b6ba8"
      ]
    }
  }

  statement {
    sid     = "GitHubProdEnvironment"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type = "Federated"
      identifiers = [
        "arn:aws:iam::919551759796:oidc-provider/token.actions.githubusercontent.com"
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
        "repo:100-hours-a-week@167328634/KTB4-4th-CLOUD@1344657749:environment:v3-prod"
      ]
    }
  }
}

resource "aws_iam_role" "v3_prod_apply" {
  name               = local.prod_role_name
  assume_role_policy = data.aws_iam_policy_document.prod_trust.json

  lifecycle {
    prevent_destroy = true
  }
}

# Production Terraform State
data "aws_iam_policy_document" "prod_state" {
  statement {
    sid       = "ListProdState"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::needu-terraform-state-919551759796"]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values = [
        "v3/prod/terraform.tfstate",
        "v3/prod/terraform.tfstate.tflock"
      ]
    }
  }

  statement {
    sid = "ReadWriteProdState"
    actions = [
      "s3:GetObject",
      "s3:PutObject"
    ]
    resources = [
      "arn:aws:s3:::needu-terraform-state-919551759796/v3/prod/terraform.tfstate"
    ]
  }

  statement {
    sid = "ManageProdStateLock"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]
    resources = [
      "arn:aws:s3:::needu-terraform-state-919551759796/v3/prod/terraform.tfstate.tflock"
    ]
  }
}

resource "aws_iam_role_policy" "v3_prod_state" {
  name   = "TerraformV3ProdState"
  role   = aws_iam_role.v3_prod_apply.name
  policy = data.aws_iam_policy_document.prod_state.json
}

# Production Terraform Apply permissions
data "aws_iam_policy_document" "prod_apply" {

  # EKS Cluster / Node Group / Add-on
  statement {
    sid = "ManageProdEKS"
    actions = [
      "eks:CreateCluster",
      "eks:DeleteCluster",
      "eks:UpdateClusterConfig",
      "eks:UpdateClusterVersion",
      "eks:CreateNodegroup",
      "eks:DeleteNodegroup",
      "eks:UpdateNodegroupConfig",
      "eks:UpdateNodegroupVersion",
      "eks:CreateAddon",
      "eks:DeleteAddon",
      "eks:UpdateAddon",
      "eks:CreateAccessEntry",
      "eks:DeleteAccessEntry",
      "eks:UpdateAccessEntry",
      "eks:AssociateAccessPolicy",
      "eks:DisassociateAccessPolicy",
      "eks:TagResource",
      "eks:UntagResource"
    ]

    resources = [
      "arn:aws:eks:${local.region}:${local.account_id}:cluster/${local.prod_prefix}",
      "arn:aws:eks:${local.region}:${local.account_id}:nodegroup/${local.prod_prefix}/*",
      "arn:aws:eks:${local.region}:${local.account_id}:addon/${local.prod_prefix}/*",
      "arn:aws:eks:${local.region}:${local.account_id}:access-entry/${local.prod_prefix}/*",
      "arn:aws:eks:${local.region}:${local.account_id}:podidentityassociation/${local.prod_prefix}/*"
    ]
  }

  # EKS Cluster / Node IAM Roles
  statement {
    sid = "ManageProdClusterNodeRoles"
    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:TagRole",
      "iam:UntagRole"
    ]

    resources = [
      "arn:aws:iam::${local.account_id}:role/${local.prod_prefix}-cluster-role",
      "arn:aws:iam::${local.account_id}:role/${local.prod_prefix}-node-role"
    ]
  }

  # ALB Controller IAM Role
  statement {
    sid = "ManageProdALBControllerRole"
    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:TagRole",
      "iam:UntagRole"
    ]

    resources = [
      "arn:aws:iam::${local.account_id}:role/${local.prod_prefix}-alb-controller"
    ]
  }

  # ALB Controller IAM Managed Policy
  statement {
    sid = "ManageProdALBControllerPolicy"
    actions = [
      "iam:CreatePolicy",
      "iam:DeletePolicy",
      "iam:CreatePolicyVersion",
      "iam:DeletePolicyVersion",
      "iam:SetDefaultPolicyVersion",
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:ListPolicyVersions",
      "iam:TagPolicy",
      "iam:UntagPolicy"
    ]

    resources = [
      "arn:aws:iam::${local.account_id}:policy/${local.prod_prefix}-alb-controller"
    ]
  }

  # Pass EKS Cluster Role
  statement {
    sid     = "PassProdClusterRole"
    actions = ["iam:PassRole"]

    resources = [
      "arn:aws:iam::${local.account_id}:role/${local.prod_prefix}-cluster-role"
    ]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["eks.amazonaws.com"]
    }
  }

  # Pass EKS Node Role
  statement {
    sid     = "PassProdNodeRole"
    actions = ["iam:PassRole"]

    resources = [
      "arn:aws:iam::${local.account_id}:role/${local.prod_prefix}-node-role"
    ]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values = [
        "eks.amazonaws.com",
        "ec2.amazonaws.com"
      ]
    }
  }

  # Pass ALB Controller Role to EKS Pod Identity
  statement {
    sid     = "PassProdALBControllerRole"
    actions = ["iam:PassRole"]

    resources = [
      "arn:aws:iam::${local.account_id}:role/${local.prod_prefix}-alb-controller"
    ]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["pods.eks.amazonaws.com"]
    }
  }

  # Create Pod Identity Association on the Prod Cluster
  statement {
    sid = "CreateProdALBPodIdentity"
    actions = [
      "eks:CreatePodIdentityAssociation",
      "eks:ListPodIdentityAssociations"
    ]

    resources = [
      "arn:aws:eks:${local.region}:${local.account_id}:cluster/${local.prod_prefix}"
    ]
  }

  # Manage Pod Identity Association
  statement {
    sid = "ManageProdALBPodIdentity"
    actions = [
      "eks:DescribePodIdentityAssociation",
      "eks:UpdatePodIdentityAssociation",
      "eks:DeletePodIdentityAssociation"
    ]

    resources = [
      "arn:aws:eks:${local.region}:${local.account_id}:podidentityassociation/${local.prod_prefix}/*"
    ]
  }

  # Create Production Network
  statement {
    sid = "CreateProdNetwork"
    actions = [
      "ec2:CreateSubnet",
      "ec2:CreateRouteTable",
      "ec2:CreateNatGateway"
    ]

    resources = [
      "arn:aws:ec2:${local.region}:${local.account_id}:subnet/*",
      "arn:aws:ec2:${local.region}:${local.account_id}:route-table/*",
      "arn:aws:ec2:${local.region}:${local.account_id}:natgateway/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/Environment"
      values   = ["prod"]
    }
  }

  statement {
    sid = "CreateNetworkInSharedVPC"
    actions = [
      "ec2:CreateSubnet",
      "ec2:CreateRouteTable",
      "ec2:CreateNatGateway"
    ]

    resources = [
      "arn:aws:ec2:${local.region}:${local.account_id}:vpc/vpc-0f2478c01e376b1b6"
    ]
  }

  # Manage Production Network
  statement {
    sid = "ManageTaggedProdNetwork"
    actions = [
      "ec2:DeleteSubnet",
      "ec2:DeleteRouteTable",
      "ec2:DeleteNatGateway",
      "ec2:CreateRoute",
      "ec2:ReplaceRoute",
      "ec2:DeleteRoute",
      "ec2:AssociateRouteTable",
      "ec2:DisassociateRouteTable",
      "ec2:CreateTags",
      "ec2:DeleteTags"
    ]

    resources = [
      "arn:aws:ec2:${local.region}:${local.account_id}:subnet/*",
      "arn:aws:ec2:${local.region}:${local.account_id}:route-table/*",
      "arn:aws:ec2:${local.region}:${local.account_id}:natgateway/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "ec2:ResourceTag/Environment"
      values   = ["prod"]
    }
  }

  statement {
    sid     = "TagProdNetworkAtCreation"
    actions = ["ec2:CreateTags"]

    resources = [
      "arn:aws:ec2:${local.region}:${local.account_id}:subnet/*",
      "arn:aws:ec2:${local.region}:${local.account_id}:route-table/*",
      "arn:aws:ec2:${local.region}:${local.account_id}:natgateway/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "ec2:CreateAction"
      values = [
        "CreateSubnet",
        "CreateRouteTable",
        "CreateNatGateway"
      ]
    }
  }

  # Terraform Resource Read
  statement {
    sid = "ReadTerraformResources"
    actions = [
      "ec2:Describe*",
      "eks:Describe*",
      "eks:List*",
      "iam:GetRole",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:ListRoleTags"
    ]

    resources = ["*"]
  }

  statement {
    sid = "ManageProdEKSSecurityGroupIngress"
    actions = [
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupIngress"
    ]
    resources = [
      "arn:aws:ec2:${local.region}:${local.account_id}:security-group/sg-06867e8d11c60ce9d"
    ]
  }

  statement {
    sid       = "CreateProdEKSSecurityGroupRule"
    actions   = ["ec2:AuthorizeSecurityGroupIngress"]
    resources = ["arn:aws:ec2:${local.region}:${local.account_id}:security-group-rule/*"]
  }

  statement {
    sid       = "TagProdEKSSecurityGroupRuleOnCreation"
    actions   = ["ec2:CreateTags"]
    resources = ["arn:aws:ec2:${local.region}:${local.account_id}:security-group-rule/*"]

    condition {
      test     = "StringEquals"
      variable = "ec2:CreateAction"
      values   = ["AuthorizeSecurityGroupIngress"]
    }
  }
}

resource "aws_iam_role_policy" "v3_prod_apply" {
  name   = "TerraformV3ProdApply"
  role   = aws_iam_role.v3_prod_apply.name
  policy = data.aws_iam_policy_document.prod_apply.json
}
