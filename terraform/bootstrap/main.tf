
terraform {
  required_version = "~> 1.16.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-2"
}

# 현재 AWS 계정 ID 조회
data "aws_caller_identity" "current" {}

locals {
  state_bucket_name = "needu-terraform-state-${data.aws_caller_identity.current.account_id}"
}

# Terraform State 저장용 S3 버킷
resource "aws_s3_bucket" "state" {
  bucket = local.state_bucket_name

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name      = local.state_bucket_name
    Project   = "NeedU"
    ManagedBy = "Terraform"
    Purpose   = "TerraformState"
  }
}

# State 파일 변경 이력 보존
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# S3 서버 측 암호화
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# 외부 공개 차단
resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# HTTP 접근 차단 및 HTTPS 강제
data "aws_iam_policy_document" "state_bucket" {
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["s3:*"]

    resources = [
      aws_s3_bucket.state.arn,
      "${aws_s3_bucket.state.arn}/*"
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "deny_insecure" {
  bucket = aws_s3_bucket.state.id
  policy = data.aws_iam_policy_document.state_bucket.json

  depends_on = [
    aws_s3_bucket_public_access_block.state
  ]
}

output "state_bucket_name" {
  description = "Terraform State S3 버킷 이름"
  value       = aws_s3_bucket.state.id
}

output "state_bucket_arn" {
  description = "Terraform State S3 버킷 ARN"
  value       = aws_s3_bucket.state.arn
}
