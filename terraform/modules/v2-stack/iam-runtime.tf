# ECS Task가 이 IAM Role들을 맡을 수 있도록 허용하는 공통 신뢰 정책
data "aws_iam_policy_document" "ecs_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

locals {
  # V1과 동시에 운영하는 동안 V2 설정이 기존 Parameter에 영향을 주지 않도록 경로를 분리
  parameter_base_path = "/needu/v2/${var.environment}"

  execution_roles = {
    frontend = {
      parameter_path = "${local.parameter_base_path}/frontend-runtime/*"
      secret_arns    = []
    }
    backend = {
      parameter_path = "${local.parameter_base_path}/backend/*"
      secret_arns    = [aws_db_instance.mysql.master_user_secret[0].secret_arn]
    }
    ai = {
      parameter_path = "${local.parameter_base_path}/ai/*"
      secret_arns    = []
    }
    catalog-sync = {
      parameter_path = "${local.parameter_base_path}/ai-catalog/*"
      secret_arns    = [aws_db_instance.mysql.master_user_secret[0].secret_arn]
    }
    catalog-import = {
      parameter_path = "${local.parameter_base_path}/ai-catalog/*"
      secret_arns    = []
    }
  }
}

# 서비스와 카탈로그 작업이 서로의 설정을 읽지 못하도록 실행 Role을 분리
resource "aws_iam_role" "service_execution" {
  for_each           = local.execution_roles
  name               = "needu-${var.environment}-${each.key}-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
}

# 모든 컨테이너에 공통으로 ECR 이미지 다운로드와 CloudWatch Logs 전송 권한 부여
resource "aws_iam_role_policy_attachment" "service_execution" {
  for_each   = local.execution_roles
  role       = aws_iam_role.service_execution[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# 각 컨테이너가 자기 Parameter 경로와 필요한 RDS 비밀값만 읽도록 제한
resource "aws_iam_role_policy" "service_execution_parameters" {
  for_each = local.execution_roles
  name     = "needu-${var.environment}-${each.key}-parameters"
  role     = aws_iam_role.service_execution[each.key].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [{
        Effect   = "Allow"
        Action   = ["ssm:GetParameter", "ssm:GetParameters"]
        Resource = ["arn:aws:ssm:*:*:parameter${each.value.parameter_path}"]
      }],
      length(each.value.secret_arns) == 0 ? [] : [{
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = each.value.secret_arns
      }]
    )
  })
}

# Frontend, Backend, AI 애플리케이션이 실행 중 사용할 Task Role을 각각 만듦
resource "aws_iam_role" "task" {
  for_each           = toset(["frontend", "backend", "ai"])
  name               = "needu-${var.environment}-${each.key}-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
}

# Catalog Sync와 Import가 서로 다른 AWS 권한을 사용하도록 Task Role을 분리
resource "aws_iam_role" "catalog_task" {
  for_each           = toset(["catalog-sync", "catalog-import"])
  name               = "needu-${var.environment}-${each.key}-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
}

# Catalog Sync는 input 경로에 결과물을 쓰는 권한만 사용
resource "aws_iam_role_policy" "catalog_sync" {
  name   = "catalog-input-write"
  role   = aws_iam_role.catalog_task["catalog-sync"].id
  policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Action = ["s3:PutObject"], Resource = ["${aws_s3_bucket.catalog.arn}/jobs/*/input/*"] }] })
}

# Catalog Import는 output 경로의 결과물을 읽는 권한만 사용
resource "aws_iam_role_policy" "catalog_import" {
  name   = "catalog-output-read"
  role   = aws_iam_role.catalog_task["catalog-import"].id
  policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Action = ["s3:GetObject"], Resource = ["${aws_s3_bucket.catalog.arn}/jobs/*/output/*"] }] })
}
