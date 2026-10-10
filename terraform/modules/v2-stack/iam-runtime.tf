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

# Frontend, Backend, AI 애플리케이션이 실행 중 사용할 Task Role을 각각 만듦
resource "aws_iam_role" "task" {
  for_each           = toset(["frontend", "backend", "ai"])
  name               = "needu-${var.environment}-${each.key}-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
}

# AI가 카탈로그 S3 버킷의 파일을 조회하고 저장할 수 있도록 허용
resource "aws_iam_role_policy" "task_catalog" {
  name   = "catalog-access"
  role   = aws_iam_role.task["ai"].id
  policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Action = ["s3:ListBucket"], Resource = [aws_s3_bucket.catalog.arn] }, { Effect = "Allow", Action = ["s3:GetObject", "s3:PutObject"], Resource = ["${aws_s3_bucket.catalog.arn}/*"] }] })
}

# Backend와 AI가 각자 필요한 데이터베이스 비밀값을 읽을 수 있도록 허용
resource "aws_iam_role_policy" "task_secrets" {
  for_each = toset(["backend", "ai"])
  name     = "database-secret-read"
  role     = aws_iam_role.task[each.key].id
  policy   = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Action = ["secretsmanager:GetSecretValue"], Resource = each.key == "backend" ? [aws_db_instance.mysql.master_user_secret[0].secret_arn] : [aws_db_instance.postgres.master_user_secret[0].secret_arn, aws_db_instance.mysql.master_user_secret[0].secret_arn] }] })
}
