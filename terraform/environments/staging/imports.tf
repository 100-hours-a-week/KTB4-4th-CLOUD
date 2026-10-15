# 기존에 생성된 Staging 서비스 로그 그룹을 Terraform State에 편입한다.
# 로그와 보존 기간은 유지하고 이후 설정만 Terraform에서 관리한다.
import {
  to = module.v2.aws_cloudwatch_log_group.service["frontend"]
  id = "/needu/staging/frontend"
}

import {
  to = module.v2.aws_cloudwatch_log_group.service["backend"]
  id = "/needu/staging/backend"
}

import {
  to = module.v2.aws_cloudwatch_log_group.service["ai"]
  id = "/needu/staging/ai"
}
