locals {
  # 비밀이 아닌 Frontend 런타임 설정은 Terraform에서 환경별로 생성
  frontend_runtime_parameters = {
    BACKEND_API_BASE_URL = "https://${var.domain_name}/api"
    SENTRY_ENVIRONMENT = {
      dev     = "development"
      staging = "staging"
      prod    = "production"
    }[var.environment]
  }
}

# V1과 분리된 V2 경로에 Frontend 런타임 Parameter를 등록
resource "aws_ssm_parameter" "frontend_runtime" {
  for_each = local.frontend_runtime_parameters

  name  = "${local.parameter_base_path}/frontend-runtime/${each.key}"
  type  = "String"
  value = each.value

  tags = {
    Name = "needu-${var.environment}-frontend-${lower(replace(each.key, "_", "-"))}"
  }
}
