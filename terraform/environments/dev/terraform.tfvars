# ==================================================
# NeedU V2 - Dev Environment
# ==================================================

environment = "dev"

# ==================================================
# Network
# ==================================================

public_subnets = {
  a = {
    az   = "ap-northeast-2a"
    cidr = "10.1.32.0/24"
  }

  c = {
    az   = "ap-northeast-2c"
    cidr = "10.1.33.0/24"
  }
}

db_subnets = {
  a = {
    az   = "ap-northeast-2a"
    cidr = "10.1.36.0/24"
  }

  c = {
    az   = "ap-northeast-2c"
    cidr = "10.1.37.0/24"
  }
}

# ==================================================
# Domain
# ==================================================

hosted_zone_id = "Z10258582M6TRCEOCUBUW"
domain_name    = "dev.needu.gift"

# ==================================================
# ECR Repositories
# ==================================================

ecr_repository_urls = {
  frontend = "919551759796.dkr.ecr.ap-northeast-2.amazonaws.com/need-u/frontend"
  backend  = "919551759796.dkr.ecr.ap-northeast-2.amazonaws.com/need-u/backend"
  ai       = "919551759796.dkr.ecr.ap-northeast-2.amazonaws.com/need-u/ai"
}

# ==================================================
# Terraform Baseline Image Tags
#
# 최초 Task Definition 생성용 이미지 태그
#
# 이후 이미지 배포는 GitHub Actions CD에서 수행
# Terraform Apply마다 이미지 태그를 변경하지 않음
#
# 실제 ECR에 존재하는 태그로 교체 필요
# ==================================================

image_tags = {
  frontend = "9d4001cb8698203eb781bf493d6eca8c7008d722"
  backend  = "9dd8711bb29b80a98eef3ebde3df15ae7d9924f7"
  ai       = "b60fb08c350c8076aa546f710566da5d631f89f5"
}

# ==================================================
# RDS
# ==================================================

mysql_engine_version    = "8.4.11"
postgres_engine_version = "18.6"

mysql_instance_class    = "db.t4g.small"
postgres_instance_class = "db.t4g.small"

mysql_storage_gb    = 50
postgres_storage_gb = 20

multi_az                 = false
deletion_protection      = false
db_backup_retention_days = 7

# ==================================================
# ElastiCache
# ==================================================

redis_node_type = "cache.t4g.micro"
redis_num_nodes = 1

# ==================================================
# ECS Task Resources
# ==================================================

task_cpu = {
  frontend = 512
  backend  = 1024
  ai       = 512
}

task_memory = {
  frontend = 1024
  backend  = 2048
  ai       = 1024
}

task_desired_count = 1

# ==================================================
# ECS Auto Scaling
# ==================================================

autoscaling_min = 1
autoscaling_max = 2

# ==================================================
# Monitoring
# ==================================================

deployment_5xx_threshold = 5

# ==================================================
# GitHub OIDC
# ==================================================

github_subject_prefixes = {
  frontend = "repo:100-hours-a-week@167328634/KTB4-4th-FE@1344651837"
  backend  = "repo:100-hours-a-week@167328634/KTB4-4th-BE@1344652257"
  ai       = "repo:100-hours-a-week@167328634/KTB4-4th-AI@1344652688"
}

github_oidc_provider_arn = "arn:aws:iam::919551759796:oidc-provider/token.actions.githubusercontent.com"

# ==================================================
# SSM Application Secrets
#
# 실제 Secret 값은 AWS에 별도 등록
# 여기에는 Parameter 경로만 설정
# ==================================================

app_secret_parameters = {
  frontend = {}
  backend = {
    AI_SERVICE_TOKEN          = "/needu/v2/dev/backend/AI_SERVICE_TOKEN"
    JWT_SECRET                = "/needu/v2/dev/backend/JWT_SECRET"
    KAKAO_CLIENT_SECRET       = "/needu/v2/dev/backend/KAKAO_CLIENT_SECRET"
    KAKAO_FRIEND_REDIRECT_URI = "/needu/v2/dev/backend/KAKAO_FRIEND_REDIRECT_URI"
    KAKAO_REDIRECT_URI        = "/needu/v2/dev/backend/KAKAO_REDIRECT_URI"
    KAKAO_REST_API_KEY        = "/needu/v2/dev/backend/KAKAO_REST_API_KEY"
    SENTRY_DSN                = "/needu/v2/dev/backend/SENTRY_DSN"
  }
  ai = {
    EXTRACTION_MODEL_BASE_URL = "/needu/v2/dev/ai/EXTRACTION_MODEL_BASE_URL"
    EXTRACTION_MODEL_NAME     = "/needu/v2/dev/ai/EXTRACTION_MODEL_NAME"
    JUDGMENT_MODEL_BASE_URL   = "/needu/v2/dev/ai/JUDGMENT_MODEL_BASE_URL"
    JUDGMENT_MODEL_NAME       = "/needu/v2/dev/ai/JUDGMENT_MODEL_NAME"
    OPENROUTER_API_KEY        = "/needu/v2/dev/ai/OPENROUTER_API_KEY"
    RESPONSE_MODEL_BASE_URL   = "/needu/v2/dev/ai/RESPONSE_MODEL_BASE_URL"
    RESPONSE_MODEL_NAME       = "/needu/v2/dev/ai/RESPONSE_MODEL_NAME"
    SERVICE_TOKEN             = "/needu/v2/dev/ai/SERVICE_TOKEN"
    UPSTAGE_API_KEY           = "/needu/v2/dev/ai/UPSTAGE_API_KEY"
  }
}

# V2 배치용 모델 Endpoint와 실행 방식 확정 전에는 빈 값으로 유지
catalog_commands = {}
