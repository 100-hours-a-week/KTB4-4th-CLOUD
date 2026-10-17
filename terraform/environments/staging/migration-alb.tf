locals {
  staging_cutover_v1_weight = var.staging_cutover_initial_target == "v1" ? 100 : 0
  staging_cutover_v2_weight = var.staging_cutover_initial_target == "v2" ? 100 : 0
}

resource "aws_lb_target_group" "v1_staging" {
  name                 = "needu-staging-v1"
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
    Name    = "needu-staging-v1"
    Purpose = "StagingCutover"
  }
}

resource "aws_lb_target_group_attachment" "v1_staging" {
  target_group_arn = aws_lb_target_group.v1_staging.arn
  target_id        = var.v1_staging_migration_network.app_private_ip
  port             = 443

  depends_on = [
    aws_route.v2_public_to_v1_staging,
    aws_vpc_security_group_egress_rule.alb_to_v1_https,
    aws_vpc_security_group_ingress_rule.v1_https_from_v2_alb
  ]
}

# Keep v2.needu.gift as a direct V2 verification endpoint. Only staging.needu.gift is switched.
resource "aws_lb_listener_rule" "staging_api_cutover" {
  listener_arn = module.v2.https_listener_arn
  priority     = 5

  action {
    type = "forward"

    forward {
      target_group {
        arn    = aws_lb_target_group.v1_staging.arn
        weight = local.staging_cutover_v1_weight
      }

      target_group {
        arn    = module.v2.backend_target_group_arn
        weight = local.staging_cutover_v2_weight
      }
    }
  }

  condition {
    host_header {
      values = ["staging.needu.gift"]
    }
  }

  condition {
    path_pattern {
      values = ["/api/v1/*"]
    }
  }

  lifecycle {
    # Runtime weights are controlled by the Staging ALB Cutover workflow.
    ignore_changes = [action]
  }

  tags = {
    Name    = "needu-staging-api-cutover"
    Purpose = "StagingCutover"
  }
}

resource "aws_lb_listener_rule" "staging_frontend_cutover" {
  listener_arn = module.v2.https_listener_arn
  priority     = 20

  action {
    type = "forward"

    forward {
      target_group {
        arn    = aws_lb_target_group.v1_staging.arn
        weight = local.staging_cutover_v1_weight
      }

      target_group {
        arn    = module.v2.frontend_target_group_arn
        weight = local.staging_cutover_v2_weight
      }
    }
  }

  condition {
    host_header {
      values = ["staging.needu.gift"]
    }
  }

  condition {
    path_pattern {
      values = ["/*"]
    }
  }

  lifecycle {
    # Runtime weights are controlled by the Staging ALB Cutover workflow.
    ignore_changes = [action]
  }

  tags = {
    Name    = "needu-staging-frontend-cutover"
    Purpose = "StagingCutover"
  }
}

output "staging_cutover" {
  description = "Resources used by the staging ALB cutover workflows"
  value = {
    listener_arn              = module.v2.https_listener_arn
    v1_target_group_arn       = aws_lb_target_group.v1_staging.arn
    frontend_target_group_arn = module.v2.frontend_target_group_arn
    backend_target_group_arn  = module.v2.backend_target_group_arn
    api_rule_arn              = aws_lb_listener_rule.staging_api_cutover.arn
    frontend_rule_arn         = aws_lb_listener_rule.staging_frontend_cutover.arn
  }
}
