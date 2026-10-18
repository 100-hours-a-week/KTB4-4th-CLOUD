locals {
  prod_cutover_v1_weight = var.prod_cutover_initial_target == "v1" ? 100 : 0
  prod_cutover_v2_weight = var.prod_cutover_initial_target == "v2" ? 100 : 0
  prod_cutover_hosts     = ["prod.needu.gift", "needu.gift"]
}

resource "aws_lb_target_group" "v1_prod" {
  name                 = "needu-prod-v1"
  port                 = 443
  protocol             = "HTTPS"
  target_type          = "ip"
  vpc_id               = module.v2.vpc_id
  deregistration_delay = 30

  health_check {
    enabled             = true
    protocol            = "HTTPS"
    path                = "/"
    matcher             = "200-399"
    interval            = 10
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name    = "needu-prod-v1"
    Purpose = "ProdCutover"
  }
}

resource "aws_lb_target_group_attachment" "v1_prod" {
  target_group_arn  = aws_lb_target_group.v1_prod.arn
  target_id         = var.v1_prod_migration_network.app_private_ip
  port              = 443
  availability_zone = "all"

  depends_on = [
    aws_route.v2_prod_public_to_v1,
    aws_vpc_security_group_egress_rule.prod_alb_to_v1_https,
    aws_vpc_security_group_ingress_rule.v1_prod_https_from_v2_alb
  ]
}

resource "aws_lb_listener_rule" "prod_api_cutover" {
  listener_arn = module.v2.https_listener_arn
  priority     = 5

  action {
    type = "forward"

    forward {
      target_group {
        arn    = aws_lb_target_group.v1_prod.arn
        weight = local.prod_cutover_v1_weight
      }

      target_group {
        arn    = module.v2.backend_target_group_arn
        weight = local.prod_cutover_v2_weight
      }
    }
  }

  condition {
    host_header {
      values = local.prod_cutover_hosts
    }
  }

  condition {
    path_pattern {
      values = ["/api/v1/*"]
    }
  }

  lifecycle {
    # 실제 전환 가중치는 Prod ALB Cutover 워크플로가 관리합니다.
    ignore_changes = [action]
  }

  tags = {
    Name    = "needu-prod-api-cutover"
    Purpose = "ProdCutover"
  }
}

resource "aws_lb_listener_rule" "prod_frontend_cutover" {
  listener_arn = module.v2.https_listener_arn
  priority     = 20

  action {
    type = "forward"

    forward {
      target_group {
        arn    = aws_lb_target_group.v1_prod.arn
        weight = local.prod_cutover_v1_weight
      }

      target_group {
        arn    = module.v2.frontend_target_group_arn
        weight = local.prod_cutover_v2_weight
      }
    }
  }

  condition {
    host_header {
      values = local.prod_cutover_hosts
    }
  }

  condition {
    path_pattern {
      values = ["/*"]
    }
  }

  lifecycle {
    # 실제 전환 가중치는 Prod ALB Cutover 워크플로가 관리합니다.
    ignore_changes = [action]
  }

  tags = {
    Name    = "needu-prod-frontend-cutover"
    Purpose = "ProdCutover"
  }
}

output "prod_cutover" {
  description = "Prod ALB Cutover 워크플로에서 사용하는 리소스"
  value = {
    listener_arn              = module.v2.https_listener_arn
    v1_target_group_arn       = aws_lb_target_group.v1_prod.arn
    frontend_target_group_arn = module.v2.frontend_target_group_arn
    backend_target_group_arn  = module.v2.backend_target_group_arn
    api_rule_arn              = aws_lb_listener_rule.prod_api_cutover.arn
    frontend_rule_arn         = aws_lb_listener_rule.prod_frontend_cutover.arn
  }
}
