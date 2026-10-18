# 수동 생성한 Bastion의 Prod MySQL 접근 규칙을 State에 편입합니다.
import {
  to = aws_vpc_security_group_egress_rule.ssm_to_prod_mysql
  id = "sgr-0b72452549a92052e"
}

import {
  to = aws_vpc_security_group_ingress_rule.prod_mysql_from_ssm
  id = "sgr-06da12bab9a857d4c"
}
