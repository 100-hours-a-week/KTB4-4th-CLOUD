# ECS 애플리케이션 런타임을 환경별로 비활성화할 수 있도록 count를 추가하면서
# 기존 Staging·Production 리소스가 교체되지 않게 기존 주소를 첫 번째 인스턴스로 옮긴다.

moved {
  from = aws_service_discovery_http_namespace.connect
  to   = aws_service_discovery_http_namespace.connect[0]
}

moved {
  from = aws_lb.main
  to   = aws_lb.main[0]
}

moved {
  from = aws_lb_target_group.fe
  to   = aws_lb_target_group.fe[0]
}

moved {
  from = aws_lb_target_group.be
  to   = aws_lb_target_group.be[0]
}

moved {
  from = aws_lb_listener.http
  to   = aws_lb_listener.http[0]
}

moved {
  from = aws_lb_listener.https
  to   = aws_lb_listener.https[0]
}

moved {
  from = aws_lb_listener_rule.api
  to   = aws_lb_listener_rule.api[0]
}

moved {
  from = aws_lb_listener_rule.websocket
  to   = aws_lb_listener_rule.websocket[0]
}

moved {
  from = aws_security_group.alb
  to   = aws_security_group.alb[0]
}

moved {
  from = aws_security_group.fe
  to   = aws_security_group.fe[0]
}

moved {
  from = aws_security_group.be
  to   = aws_security_group.be[0]
}

moved {
  from = aws_security_group.ai
  to   = aws_security_group.ai[0]
}

moved {
  from = aws_vpc_security_group_ingress_rule.alb_https
  to   = aws_vpc_security_group_ingress_rule.alb_https[0]
}

moved {
  from = aws_vpc_security_group_ingress_rule.alb_http
  to   = aws_vpc_security_group_ingress_rule.alb_http[0]
}

moved {
  from = aws_vpc_security_group_egress_rule.alb_to_fe
  to   = aws_vpc_security_group_egress_rule.alb_to_fe[0]
}

moved {
  from = aws_vpc_security_group_egress_rule.alb_to_be
  to   = aws_vpc_security_group_egress_rule.alb_to_be[0]
}

moved {
  from = aws_vpc_security_group_ingress_rule.fe_from_alb
  to   = aws_vpc_security_group_ingress_rule.fe_from_alb[0]
}

moved {
  from = aws_vpc_security_group_ingress_rule.be_from_alb
  to   = aws_vpc_security_group_ingress_rule.be_from_alb[0]
}

moved {
  from = aws_vpc_security_group_ingress_rule.ai_from_be
  to   = aws_vpc_security_group_ingress_rule.ai_from_be[0]
}

moved {
  from = aws_vpc_security_group_ingress_rule.mysql_from_be
  to   = aws_vpc_security_group_ingress_rule.mysql_from_be[0]
}

moved {
  from = aws_vpc_security_group_ingress_rule.postgres_from_ai
  to   = aws_vpc_security_group_ingress_rule.postgres_from_ai[0]
}

moved {
  from = aws_vpc_security_group_ingress_rule.redis_from_be
  to   = aws_vpc_security_group_ingress_rule.redis_from_be[0]
}

moved {
  from = aws_vpc_security_group_ingress_rule.redis_from_ai
  to   = aws_vpc_security_group_ingress_rule.redis_from_ai[0]
}

moved {
  from = aws_cloudwatch_metric_alarm.alb_5xx
  to   = aws_cloudwatch_metric_alarm.alb_5xx[0]
}

moved {
  from = aws_cloudwatch_metric_alarm.backend_target_5xx
  to   = aws_cloudwatch_metric_alarm.backend_target_5xx[0]
}

moved {
  from = aws_cloudwatch_metric_alarm.ai_service_connect_5xx
  to   = aws_cloudwatch_metric_alarm.ai_service_connect_5xx[0]
}
