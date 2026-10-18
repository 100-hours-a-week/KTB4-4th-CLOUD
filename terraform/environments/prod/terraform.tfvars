# Git에서 관리하는 V2 Prod 고정 설정
# GitHub CD 저장소는 확정 후 이 파일에 추가하고,
# 배포 이미지 태그는 CI에서 TF_VAR_image_tags로 전달합니다.

environment = "prod"

# V1 Prod와 V2 공통 VPC 사이의 기존 Peering을 재사용한다.
# 두 V2 환경이 같은 VPC를 사용하므로 별도의 Peering을 만들지 않는다.
v1_prod_migration_network = {
  peering_connection_id = "pcx-054d267c5e20dcc78"
  vpc_cidr              = "10.0.0.0/16"
  security_group_id     = "sg-0ed5c197b7041c81d"
  mysql_private_ip      = "10.0.5.11"
  app_private_ip        = "10.0.5.11"
}

# 최초 생성 시 실제 운영 트래픽은 계속 V1으로 전달한다.
prod_cutover_initial_target = "v1"

public_subnets = {
  a = { az = "ap-northeast-2a", cidr = "10.1.16.0/24" }
  c = { az = "ap-northeast-2c", cidr = "10.1.17.0/24" }
}

db_subnets = {
  a = { az = "ap-northeast-2a", cidr = "10.1.20.0/24" }
  c = { az = "ap-northeast-2c", cidr = "10.1.21.0/24" }
}

hosted_zone_id = "Z10258582M6TRCEOCUBUW"
domain_name    = "prod.needu.gift"

ecr_repository_urls = {
  frontend = "919551759796.dkr.ecr.ap-northeast-2.amazonaws.com/need-u/frontend"
  backend  = "919551759796.dkr.ecr.ap-northeast-2.amazonaws.com/need-u/backend"
  ai       = "919551759796.dkr.ecr.ap-northeast-2.amazonaws.com/need-u/ai"
}

# 최초 Task Definition 생성에 사용할 ECR 이미지 태그
image_tags = {
  frontend = "9d4001cb8698203eb781bf493d6eca8c7008d722"
  backend  = "9dd8711bb29b80a98eef3ebde3df15ae7d9924f7"
  ai       = "b60fb08c350c8076aa546f710566da5d631f89f5"
}

mysql_engine_version    = "8.4.11"
postgres_engine_version = "18.6" # pgvector 0.8.2 지원 버전
mysql_instance_class    = "db.t4g.medium"
postgres_instance_class = "db.t4g.small"
mysql_storage_gb        = 50
mysql_parameter_group = {
  name                      = "needu-prod-mysql84"
  description               = "NeedU Prod MySQL 8.4 parameters"
  net_read_timeout_seconds  = 300
  net_write_timeout_seconds = 300
}
postgres_storage_gb = 20
redis_node_type     = "cache.t4g.small"
redis_num_nodes     = 1
task_cpu            = { frontend = 512, backend = 1024, ai = 512 }
task_memory         = { frontend = 1024, backend = 2048, ai = 1024 }
# 최초 Apply에서는 RDS와 런타임 리소스만 생성한다.
# Prod DB URL 등록과 통합 검증 후 2로 올려 ECS를 기동한다.
task_desired_count       = 0
autoscaling_min          = 0
autoscaling_max          = 4
multi_az                 = false
deletion_protection      = true
db_backup_retention_days = 7
deployment_5xx_threshold = 5

github_oidc_provider_arn = "arn:aws:iam::919551759796:oidc-provider/token.actions.githubusercontent.com"

github_subject_prefixes = {
  frontend = "repo:100-hours-a-week@167328634/KTB4-4th-FE@1344651837"
  backend  = "repo:100-hours-a-week@167328634/KTB4-4th-BE@1344652257"
  ai       = "repo:100-hours-a-week@167328634/KTB4-4th-AI@1344652688"
}

# 실제 값은 AWS에 별도 등록하고 여기에는 Parameter 경로만 작성
app_secret_parameters = {
  frontend = {}
  backend = {
    AI_SERVICE_TOKEN           = "/needu/v2/prod/backend/AI_SERVICE_TOKEN"
    JWT_SECRET                 = "/needu/v2/prod/backend/JWT_SECRET"
    KAKAO_ADMIN_KEY            = "/needu/v2/prod/backend/KAKAO_ADMIN_KEY"
    KAKAO_CLIENT_SECRET        = "/needu/v2/prod/backend/KAKAO_CLIENT_SECRET"
    KAKAO_FRIEND_REDIRECT_URI  = "/needu/v2/prod/backend/KAKAO_FRIEND_REDIRECT_URI"
    KAKAO_REDIRECT_URI         = "/needu/v2/prod/backend/KAKAO_REDIRECT_URI"
    KAKAO_REST_API_KEY         = "/needu/v2/prod/backend/KAKAO_REST_API_KEY"
    KAKAO_TOKEN_ENCRYPTION_KEY = "/needu/v2/prod/backend/KAKAO_TOKEN_ENCRYPTION_KEY"
    SENTRY_DSN                 = "/needu/v2/prod/backend/SENTRY_DSN"
    VAPID_PRIVATE_KEY          = "/needu/v2/prod/backend/VAPID_PRIVATE_KEY"
    VAPID_PUBLIC_KEY           = "/needu/v2/prod/backend/VAPID_PUBLIC_KEY"
    VAPID_SUBJECT              = "/needu/v2/prod/backend/VAPID_SUBJECT"
    WEB_PUSH_ENABLED           = "/needu/v2/prod/backend/WEB_PUSH_ENABLED"
    WEB_PUSH_REQUEST_TIMEOUT   = "/needu/v2/prod/backend/WEB_PUSH_REQUEST_TIMEOUT"
    WEB_PUSH_TTL               = "/needu/v2/prod/backend/WEB_PUSH_TTL"
  }
  ai = {
    EXTRACTION_MODEL_BASE_URL          = "/needu/v2/prod/ai/EXTRACTION_MODEL_BASE_URL"
    EXTRACTION_MODEL_NAME              = "/needu/v2/prod/ai/EXTRACTION_MODEL_NAME"
    JUDGMENT_MODEL_BASE_URL            = "/needu/v2/prod/ai/JUDGMENT_MODEL_BASE_URL"
    JUDGMENT_MODEL_NAME                = "/needu/v2/prod/ai/JUDGMENT_MODEL_NAME"
    OPENROUTER_API_KEY                 = "/needu/v2/prod/ai/OPENROUTER_API_KEY"
    RESPONSE_MODEL_BASE_URL            = "/needu/v2/prod/ai/RESPONSE_MODEL_BASE_URL"
    RESPONSE_MODEL_NAME                = "/needu/v2/prod/ai/RESPONSE_MODEL_NAME"
    SERVICE_TOKEN                      = "/needu/v2/prod/ai/SERVICE_TOKEN"
    UPSTAGE_API_KEY                    = "/needu/v2/prod/ai/UPSTAGE_API_KEY"
    RUNPOD_API_KEY                     = "/needu/v2/prod/ai/RUNPOD_API_KEY"
    RUNPOD_POD_NAME_PREFIX             = "/needu/v2/prod/ai/RUNPOD_POD_NAME_PREFIX"
    MODEL_API_KEY                      = "/needu/v2/prod/ai/MODEL_API_KEY"
    RESPONSE_FALLBACK_MODEL_BASE_URL   = "/needu/v2/prod/ai/RESPONSE_FALLBACK_MODEL_BASE_URL"
    RESPONSE_FALLBACK_MODEL_NAME       = "/needu/v2/prod/ai/RESPONSE_FALLBACK_MODEL_NAME"
    EXTRACTION_FALLBACK_MODEL_BASE_URL = "/needu/v2/prod/ai/EXTRACTION_FALLBACK_MODEL_BASE_URL"
    EXTRACTION_FALLBACK_MODEL_NAME     = "/needu/v2/prod/ai/EXTRACTION_FALLBACK_MODEL_NAME"
  }
}

# AI 팀 실행 명령 확정 전에는 빈 값으로 유지
catalog_commands = {}
