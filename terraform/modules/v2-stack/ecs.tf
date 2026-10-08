locals {
  services = {
    frontend = { port = 3000, sg = aws_security_group.fe.id }
    backend  = { port = 8080, sg = aws_security_group.be.id }
    ai       = { port = 8000, sg = aws_security_group.ai.id }
  }
  service_env = {
    frontend = merge({ NODE_ENV = "production", BACKEND_API_BASE_URL = "http://backend:8080" }, lookup(var.app_env, "frontend", {}))
    backend  = merge({ SPRING_PROFILES_ACTIVE = var.environment, AI_SERVER_BASE_URL = "http://ai:8000", DB_HOST = aws_db_instance.mysql.address, DB_PORT = "3306", DB_USERNAME = "needu", REDIS_HOST = aws_elasticache_replication_group.redis.primary_endpoint_address, REDIS_PORT = "6379", REDIS_SSL_ENABLED = "true" }, lookup(var.app_env, "backend", {}))
    ai       = merge({ APP_ENV = var.environment, POSTGRES_HOST = aws_db_instance.postgres.address, POSTGRES_PORT = "5432", POSTGRES_USER = "needu", MYSQL_HOST = aws_db_instance.mysql.address, CATALOG_BUCKET = aws_s3_bucket.catalog.bucket, REDIS_HOST = aws_elasticache_replication_group.redis.primary_endpoint_address, REDIS_SSL_ENABLED = "true" }, lookup(var.app_env, "ai", {}))
  }
}
resource "aws_ecs_cluster" "main" {
  name = "needu-${var.environment}"
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}
resource "aws_service_discovery_http_namespace" "connect" {
  name = "needu-${var.environment}"
}
resource "aws_cloudwatch_log_group" "service" {
  for_each          = local.services
  name              = "/needu/${var.environment}/${each.key}"
  retention_in_days = var.environment == "dev" ? 7 : 30
}
resource "aws_ecs_task_definition" "service" {
  for_each                 = local.services
  family                   = "needu-${var.environment}-${each.key}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.task_cpu[each.key])
  memory                   = tostring(var.task_memory[each.key])
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task[each.key].arn
  container_definitions = jsonencode([{
    name             = each.key
    image            = "${var.ecr_repository_urls[each.key]}:${var.image_tags[each.key]}"
    essential        = true
    portMappings     = [{ containerPort = each.value.port, hostPort = each.value.port, protocol = "tcp", name = "${each.key}-tcp", appProtocol = "http" }]
    environment      = [for k, v in local.service_env[each.key] : { name = k, value = v }]
    secrets          = concat([for k, v in lookup(var.app_secret_parameters, each.key, {}) : { name = k, valueFrom = v }], each.key == "backend" ? [{ name = "DB_PASSWORD", valueFrom = "${aws_db_instance.mysql.master_user_secret[0].secret_arn}:password::" }] : each.key == "ai" ? [{ name = "POSTGRES_PASSWORD", valueFrom = "${aws_db_instance.postgres.master_user_secret[0].secret_arn}:password::" }] : [])
    logConfiguration = { logDriver = "awslogs", options = { "awslogs-group" = aws_cloudwatch_log_group.service[each.key].name, "awslogs-region" = "ap-northeast-2", "awslogs-stream-prefix" = "ecs" } }
  }])
}
resource "aws_ecs_service" "service" {
  for_each                           = local.services
  name                               = "needu-${var.environment}-${each.key}"
  cluster                            = aws_ecs_cluster.main.id
  task_definition                    = aws_ecs_task_definition.service[each.key].arn
  desired_count                      = var.task_desired_count
  launch_type                        = "FARGATE"
  enable_execute_command             = true
  health_check_grace_period_seconds  = each.key == "ai" ? null : 120
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200
  network_configuration {
    subnets          = local.public_subnet_ids
    security_groups  = [each.value.sg]
    assign_public_ip = var.ecs_assign_public_ip
  }
  dynamic "load_balancer" {
    for_each = each.key == "frontend" ? [aws_lb_target_group.fe.arn] : each.key == "backend" ? [aws_lb_target_group.be.arn] : []
    content {
      target_group_arn = load_balancer.value
      container_name   = each.key
      container_port   = each.value.port
    }
  }
  service_connect_configuration {
    enabled   = true
    namespace = aws_service_discovery_http_namespace.connect.arn
    dynamic "service" {
      for_each = each.key == "ai" ? [1] : []
      content {
        port_name      = "ai-tcp"
        discovery_name = "ai"
        client_alias {
          dns_name = "ai"
          port     = 8000
        }
      }
    }
    dynamic "service" {
      for_each = each.key == "backend" ? [1] : []
      content {
        port_name      = "backend-tcp"
        discovery_name = "backend"
        client_alias {
          dns_name = "backend"
          port     = 8080
        }
      }
    }
  }
  depends_on = [aws_lb_listener.https, aws_lb_listener_rule.api]
  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }
}
resource "aws_appautoscaling_target" "ecs" {
  for_each           = local.services
  max_capacity       = var.autoscaling_max
  min_capacity       = var.autoscaling_min
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.service[each.key].name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}
resource "aws_appautoscaling_policy" "cpu" {
  for_each           = local.services
  name               = "needu-${var.environment}-${each.key}-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs[each.key].service_namespace
  target_tracking_scaling_policy_configuration {
    target_value = 65
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    scale_in_cooldown  = 180
    scale_out_cooldown = 60
  }
}
resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "needu-${var.environment}-alb-5xx"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_ELB_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 5
  treat_missing_data  = "notBreaching"
  dimensions          = { LoadBalancer = aws_lb.main.arn_suffix }
  alarm_actions       = var.alarm_sns_topic_arn == "" ? [] : [var.alarm_sns_topic_arn]
}
resource "aws_cloudwatch_log_group" "batch" {
  for_each          = toset(["catalog-sync", "catalog-import", "spring-batch"])
  name              = "/needu/${var.environment}/batch/${each.key}"
  retention_in_days = 30
}
resource "aws_ecs_task_definition" "batch" {
  for_each = {
    catalog-sync   = "ai"
    catalog-import = "ai"
    spring-batch   = "backend"
  }
  family                   = "needu-${var.environment}-${each.key}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.task_cpu[each.value])
  memory                   = tostring(var.task_memory[each.value])
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task[each.value].arn
  container_definitions = jsonencode([{
    name             = each.key
    image            = "${var.ecr_repository_urls[each.value]}:${var.image_tags[each.value]}"
    essential        = true
    environment      = [for k, v in merge(local.service_env[each.value], { NEEDU_BATCH_JOB = each.key }) : { name = k, value = v }]
    secrets          = concat([for k, v in lookup(var.app_secret_parameters, each.value, {}) : { name = k, valueFrom = v }], each.value == "backend" ? [{ name = "DB_PASSWORD", valueFrom = "${aws_db_instance.mysql.master_user_secret[0].secret_arn}:password::" }] : [{ name = "POSTGRES_PASSWORD", valueFrom = "${aws_db_instance.postgres.master_user_secret[0].secret_arn}:password::" }])
    logConfiguration = { logDriver = "awslogs", options = { "awslogs-group" = aws_cloudwatch_log_group.batch[each.key].name, "awslogs-region" = "ap-northeast-2", "awslogs-stream-prefix" = "batch" } }
  }])
}
