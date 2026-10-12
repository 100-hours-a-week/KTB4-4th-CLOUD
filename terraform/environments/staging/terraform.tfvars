# Git에서 관리하는 V2 Staging 고정 설정
# GitHub CD 저장소는 확정 후 이 파일에 추가하고,
# 배포 이미지 태그는 CI에서 TF_VAR_image_tags로 전달합니다.

environment = "staging"

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
  frontend = "9d4001cb8698203eb781bf493d6eca8c7008d722"
  backend  = "9dd8711bb29b80a98eef3ebde3df15ae7d9924f7"
  ai       = "b60fb08c350c8076aa546f710566da5d631f89f5"
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
task_desired_count       = 2
autoscaling_min          = 2
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
  backend  = {}
  ai       = {}
}

# AI 팀 실행 명령 확정 전에는 빈 값으로 유지
catalog_commands = {}
