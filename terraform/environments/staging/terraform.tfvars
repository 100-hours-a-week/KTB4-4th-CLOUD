# Git에서 관리하는 V2 Staging 고정 설정
# GitHub CD 저장소는 확정 후 이 파일에 추가하고,
# 배포 이미지 태그는 CI에서 TF_VAR_image_tags로 전달합니다.

environment = "staging"

# V1 Staging EC2 MySQL과 V2 Staging DMS 사이의 전용 네트워크 연결 정보
v1_staging_migration_network = {
  vpc_id            = "vpc-076d38543cfa2ed9c"
  vpc_cidr          = "10.0.0.0/16"
  route_table_id    = "rtb-0d966016f4dab5171"
  security_group_id = "sg-08f54201fddf75ac8"
  mysql_private_ip  = "10.0.14.126"
  app_private_ip    = "10.0.14.126"
}

# Preserve the current V2 traffic on the first apply. Runtime cutovers are managed by the workflow.
staging_cutover_initial_target = "v2"

public_subnets = {
  a = { az = "ap-northeast-2a", cidr = "10.1.48.0/24" }
  c = { az = "ap-northeast-2c", cidr = "10.1.49.0/24" }
}

db_subnets = {
  a = { az = "ap-northeast-2a", cidr = "10.1.52.0/24" }
  c = { az = "ap-northeast-2c", cidr = "10.1.53.0/24" }
}

hosted_zone_id = "Z10258582M6TRCEOCUBUW"
domain_name    = "v2.needu.gift"

ecr_repository_urls = {
  frontend = "919551759796.dkr.ecr.ap-northeast-2.amazonaws.com/need-u/frontend"
  backend  = "919551759796.dkr.ecr.ap-northeast-2.amazonaws.com/need-u/backend"
  ai       = "919551759796.dkr.ecr.ap-northeast-2.amazonaws.com/need-u/ai"
}

# 최초 Task Definition 생성에 사용할 ECR 이미지 태그
image_tags = {
  frontend = "v2-afd3be29f46bfa73ce7f3d13005b8552dcc2a7fa"
  backend  = "v2-ef2543dbcb18b4edf826ffaaac42b83efd7f53d9"
  ai       = "v2-c4c9b2471df60a368305289acf6002a9b521b67a"
}

mysql_engine_version     = "8.4.11"
postgres_engine_version  = "18.6" # pgvector 0.8.2 지원 버전
mysql_instance_class     = "db.t4g.medium"
postgres_instance_class  = "db.t4g.small"
mysql_storage_gb         = 50
postgres_storage_gb      = 20
redis_node_type          = "cache.t4g.small"
redis_num_nodes          = 1
task_cpu                 = { frontend = 512, backend = 1024, ai = 512 }
task_memory              = { frontend = 1024, backend = 2048, ai = 1024 }
task_desired_count       = 0
autoscaling_min          = 0
autoscaling_max          = 4
multi_az                 = false
deletion_protection      = false
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
    AI_CHAT_SHORT_COOLDOWN_EXTERNAL_IDS = "/needu/v2/staging/backend/AI_CHAT_SHORT_COOLDOWN_EXTERNAL_IDS"
    AI_SERVICE_TOKEN                    = "/needu/v2/staging/backend/AI_SERVICE_TOKEN"
    NEEDU_RATELIMIT_ENABLED             = "/needu/v2/staging/backend/NEEDU_RATELIMIT_ENABLED"
    JWT_SECRET                          = "/needu/v2/staging/backend/JWT_SECRET"
    KAKAO_ADMIN_KEY                     = "/needu/v2/staging/backend/KAKAO_ADMIN_KEY"
    KAKAO_CLIENT_SECRET                 = "/needu/v2/staging/backend/KAKAO_CLIENT_SECRET"
    KAKAO_FRIEND_REDIRECT_URI           = "/needu/v2/staging/backend/KAKAO_FRIEND_REDIRECT_URI"
    KAKAO_REDIRECT_URI                  = "/needu/v2/staging/backend/KAKAO_REDIRECT_URI"
    KAKAO_REST_API_KEY                  = "/needu/v2/staging/backend/KAKAO_REST_API_KEY"
    KAKAO_TOKEN_ENCRYPTION_KEY          = "/needu/v2/staging/backend/KAKAO_TOKEN_ENCRYPTION_KEY"
    SENTRY_DSN                          = "/needu/v2/staging/backend/SENTRY_DSN"
    VAPID_PRIVATE_KEY                   = "/needu/v2/staging/backend/VAPID_PRIVATE_KEY"
    VAPID_PUBLIC_KEY                    = "/needu/v2/staging/backend/VAPID_PUBLIC_KEY"
    VAPID_SUBJECT                       = "/needu/v2/staging/backend/VAPID_SUBJECT"
    WEB_PUSH_ENABLED                    = "/needu/v2/staging/backend/WEB_PUSH_ENABLED"
    WEB_PUSH_REQUEST_TIMEOUT            = "/needu/v2/staging/backend/WEB_PUSH_REQUEST_TIMEOUT"
    WEB_PUSH_TTL                        = "/needu/v2/staging/backend/WEB_PUSH_TTL"
  }
  ai = {
    EXTRACTION_MODEL_BASE_URL          = "/needu/v2/staging/ai/EXTRACTION_MODEL_BASE_URL"
    EXTRACTION_MODEL_NAME              = "/needu/v2/staging/ai/EXTRACTION_MODEL_NAME"
    JUDGMENT_MODEL_BASE_URL            = "/needu/v2/staging/ai/JUDGMENT_MODEL_BASE_URL"
    JUDGMENT_MODEL_NAME                = "/needu/v2/staging/ai/JUDGMENT_MODEL_NAME"
    OPENROUTER_API_KEY                 = "/needu/v2/staging/ai/OPENROUTER_API_KEY"
    RESPONSE_MODEL_BASE_URL            = "/needu/v2/staging/ai/RESPONSE_MODEL_BASE_URL"
    RESPONSE_MODEL_NAME                = "/needu/v2/staging/ai/RESPONSE_MODEL_NAME"
    SERVICE_TOKEN                      = "/needu/v2/staging/ai/SERVICE_TOKEN"
    UPSTAGE_API_KEY                    = "/needu/v2/staging/ai/UPSTAGE_API_KEY"
    RUNPOD_API_KEY                     = "/needu/v2/staging/ai/RUNPOD_API_KEY"
    RUNPOD_POD_NAME_PREFIX             = "/needu/v2/staging/ai/RUNPOD_POD_NAME_PREFIX"
    MODEL_API_KEY                      = "/needu/v2/staging/ai/MODEL_API_KEY"
    RESPONSE_FALLBACK_MODEL_BASE_URL   = "/needu/v2/staging/ai/RESPONSE_FALLBACK_MODEL_BASE_URL"
    RESPONSE_FALLBACK_MODEL_NAME       = "/needu/v2/staging/ai/RESPONSE_FALLBACK_MODEL_NAME"
    EXTRACTION_FALLBACK_MODEL_BASE_URL = "/needu/v2/staging/ai/EXTRACTION_FALLBACK_MODEL_BASE_URL"
    EXTRACTION_FALLBACK_MODEL_NAME     = "/needu/v2/staging/ai/EXTRACTION_FALLBACK_MODEL_NAME"
  }
}

# AI 팀 실행 명령 확정 전에는 빈 값으로 유지
catalog_commands = {}
