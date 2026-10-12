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
  frontend = "REPLACE_WITH_FRONTEND_TAG"
  backend  = "REPLACE_WITH_BACKEND_TAG"
  ai       = "REPLACE_WITH_AI_TAG"
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

github_repository = "REPLACE_WITH_OWNER/REPOSITORY"

github_oidc_provider_arn = "arn:aws:iam::919551759796:oidc-provider/token.actions.githubusercontent.com"

# ==================================================
# SSM Application Secrets
#
# 실제 Secret 값은 AWS에 별도 등록
# 여기에는 Parameter 경로만 설정
# ==================================================

app_secret_parameters = {
  frontend = {}
  backend  = {}
  ai       = {}
}

# ==================================================
# AI Catalog Batch
# ==================================================

catalog_commands = {}