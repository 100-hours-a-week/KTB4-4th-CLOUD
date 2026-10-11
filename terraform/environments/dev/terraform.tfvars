# Git에서 관리하는 Dev 고정 설정
# GitHub CD 저장소는 확정 후 이 파일에 추가하고,
# 배포 이미지 태그는 CI에서 TF_VAR_image_tags로 전달합니다.

environment = "dev"

public_subnets = {
  a = { az = "ap-northeast-2a", cidr = "10.1.32.0/24" }
  c = { az = "ap-northeast-2c", cidr = "10.1.33.0/24" }
}

db_subnets = {
  a = { az = "ap-northeast-2a", cidr = "10.1.36.0/24" }
  c = { az = "ap-northeast-2c", cidr = "10.1.37.0/24" }
}

hosted_zone_id = "Z10258582M6TRCEOCUBUW"
domain_name    = "dev.needu.gift"

ecr_repository_urls = {
  frontend = "919551759796.dkr.ecr.ap-northeast-2.amazonaws.com/need-u/frontend"
  backend  = "919551759796.dkr.ecr.ap-northeast-2.amazonaws.com/need-u/backend"
  ai       = "919551759796.dkr.ecr.ap-northeast-2.amazonaws.com/need-u/ai"
}

mysql_engine_version     = "8.4.11"
postgres_engine_version  = "18.6" # pgvector 0.8.2 지원 버전
mysql_instance_class     = "db.t4g.small"
postgres_instance_class  = "db.t4g.small"
mysql_storage_gb         = 50
postgres_storage_gb      = 20
redis_node_type          = "cache.t4g.micro"
redis_num_nodes          = 1
task_cpu                 = { frontend = 512, backend = 1024, ai = 512 }
task_memory              = { frontend = 1024, backend = 2048, ai = 1024 }
task_desired_count       = 1
autoscaling_min          = 1
autoscaling_max          = 2
multi_az                 = false
deletion_protection      = false
db_backup_retention_days = 7
deployment_5xx_threshold = 5

github_oidc_provider_arn = "arn:aws:iam::919551759796:oidc-provider/token.actions.githubusercontent.com"

# 실제 값은 AWS에 별도 등록하고 여기에는 Parameter 경로만 작성
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
