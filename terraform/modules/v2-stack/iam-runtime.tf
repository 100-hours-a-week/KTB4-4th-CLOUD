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

# ECS가 컨테이너 시작에 필요한 작업을 수행할 때 사용하는 실행 Role
resource "aws_iam_role" "execution" {
  name               = "needu-${var.environment}-ecs-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
}

# ECR 이미지 다운로드와 CloudWatch Logs 전송에 필요한 AWS 기본 정책을 연결
resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# 컨테이너 시작 시 Parameter Store와 DB 비밀값을 읽을 수 있도록 허용
resource "aws_iam_role_policy" "execution_parameters" {
  name   = "needu-${var.environment}-execution-parameters"
  role   = aws_iam_role.execution.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Action = ["ssm:GetParameters", "ssm:GetParameter", "secretsmanager:GetSecretValue"], Resource = ["arn:aws:ssm:*:*:parameter${var.parameter_prefix}/*", aws_db_instance.mysql.master_user_secret[0].secret_arn, aws_db_instance.postgres.master_user_secret[0].secret_arn] }] })
}

locals {
  execution_roles = {
    frontend = {
      parameter_path = "/needu/${var.environment}/frontend-runtime/*"
      secret_arns    = []
    }
    backend = {
      parameter_path = "/needu/${var.environment}/backend/*"
      secret_arns    = [aws_db_instance.mysql.master_user_secret[0].secret_arn]
    }
    ai = {
      parameter_path = "/needu/${var.environment}/ai/*"
      secret_arns    = [aws_db_instance.postgres.master_user_secret[0].secret_arn]
    }
    catalog-sync = {
      parameter_path = "/needu/${var.environment}/ai-catalog/*"
      secret_arns = [
        aws_db_instance.mysql.master_user_secret[0].secret_arn,
        aws_db_instance.postgres.master_user_secret[0].secret_arn
      ]
    }
    catalog-import = {
      parameter_path = "/needu/${var.environment}/ai-catalog/*"
      secret_arns    = [aws_db_instance.postgres.master_user_secret[0].secret_arn]
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

# Backend와 AI가 각자 필요한 데이터베이스 비밀값을 읽을 수 있도록 허용
resource "aws_iam_role_policy" "task_secrets" {
  for_each = toset(["backend", "ai"])
  name     = "database-secret-read"
  role     = aws_iam_role.task[each.key].id
  policy   = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Action = ["secretsmanager:GetSecretValue"], Resource = each.key == "backend" ? [aws_db_instance.mysql.master_user_secret[0].secret_arn] : [aws_db_instance.postgres.master_user_secret[0].secret_arn] }] })
}
