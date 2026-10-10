locals {
  services = {
    frontend = { port = 3000, sg = aws_security_group.fe.id }
    backend  = { port = 8080, sg = aws_security_group.be.id }
    ai       = { port = 8000, sg = aws_security_group.ai.id }
  }
  service_env = {
    frontend = merge({ NODE_ENV = "production" }, lookup(var.app_env, "frontend", {}))
    backend = merge({
      SPRING_PROFILES_ACTIVE        = var.environment
      SPRING_DATASOURCE_URL         = "jdbc:mysql://${aws_db_instance.mysql.address}:3306/needu"
      DB_USERNAME                   = "needu"
      SPRING_DATA_REDIS_HOST        = aws_elasticache_replication_group.redis.primary_endpoint_address
      SPRING_DATA_REDIS_PORT        = "6379"
      SPRING_DATA_REDIS_SSL_ENABLED = "true"
      AI_SERVER_BASE_URL            = "http://ai:8000"
    }, lookup(var.app_env, "backend", {}))
    ai = merge({
      REDIS_URL = "rediss://${aws_elasticache_replication_group.redis.primary_endpoint_address}:6379/0"
    }, lookup(var.app_env, "ai", {}))
  }
  service_secrets = {
    frontend = merge({
      BACKEND_API_BASE_URL = "/needu/${var.environment}/frontend-runtime/BACKEND_API_BASE_URL"
      SENTRY_ENVIRONMENT   = "/needu/${var.environment}/frontend-runtime/SENTRY_ENVIRONMENT"
    }, lookup(var.app_secret_parameters, "frontend", {}))
    backend = lookup(var.app_secret_parameters, "backend", {})
    ai = merge({
      CATALOG_DATABASE_URL_RO = "/needu/${var.environment}/ai/CATALOG_DATABASE_URL_RO"
    }, lookup(var.app_secret_parameters, "ai", {}))
  }
  catalog_jobs = {
    catalog-sync = {
      environment = {
        CATALOG_BUCKET        = aws_s3_bucket.catalog.bucket
        SOURCE_MYSQL_HOST     = aws_db_instance.mysql.address
        SOURCE_MYSQL_PORT     = "3306"
        SOURCE_MYSQL_USER     = "needu"
        SOURCE_MYSQL_DATABASE = "needu"
      }
      secrets = {
        CATALOG_DATABASE_URL  = "/needu/${var.environment}/ai-catalog/CATALOG_DATABASE_URL"
        SOURCE_MYSQL_PASSWORD = "${aws_db_instance.mysql.master_user_secret[0].secret_arn}:password::"
      }
    }
    catalog-import = {
      environment = {
        CATALOG_BUCKET = aws_s3_bucket.catalog.bucket
      }
      secrets = {
        CATALOG_DATABASE_URL = "/needu/${var.environment}/ai-catalog/CATALOG_DATABASE_URL"
      }
    }
  }
}
resource "aws_ecs_cluster" "main" {
  name = "needu-${var.environment}-cluster"
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
  execution_role_arn       = aws_iam_role.service_execution[each.key].arn
  task_role_arn            = aws_iam_role.task[each.key].arn
  container_definitions = jsonencode([{
    name             = each.key
    image            = "${var.ecr_repository_urls[each.key]}:${var.image_tags[each.key]}"
    essential        = true
    portMappings     = [{ containerPort = each.value.port, hostPort = each.value.port, protocol = "tcp", name = "${each.key}-tcp", appProtocol = "http" }]
    environment      = [for k, v in local.service_env[each.key] : { name = k, value = v }]
    secrets          = concat([for k, v in local.service_secrets[each.key] : { name = k, valueFrom = v }], each.key == "backend" ? [{ name = "DB_PASSWORD", valueFrom = "${aws_db_instance.mysql.master_user_secret[0].secret_arn}:password::" }] : [])
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
  enable_execute_command             = var.environment != "prod"
  health_check_grace_period_seconds  = each.key == "ai" ? null : 120
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }
  dynamic "alarms" {
    for_each = contains(["backend", "ai"], each.key) ? [each.key] : []
    content {
      alarm_names = [alarms.value == "backend" ? aws_cloudwatch_metric_alarm.backend_target_5xx.alarm_name : aws_cloudwatch_metric_alarm.ai_service_connect_5xx.alarm_name]
      enable      = true
      rollback    = true
    }
  }
  network_configuration {
    subnets          = [aws_subnet.public["a"].id]
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

resource "aws_cloudwatch_metric_alarm" "backend_target_5xx" {
  alarm_name          = "needu-${var.environment}-backend-deployment-5xx"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  datapoints_to_alarm = 2
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = var.deployment_5xx_threshold
  treat_missing_data  = "notBreaching"
  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
    TargetGroup  = aws_lb_target_group.be.arn_suffix
  }
  alarm_actions = var.alarm_sns_topic_arn == "" ? [] : [var.alarm_sns_topic_arn]
}

resource "aws_cloudwatch_metric_alarm" "ai_service_connect_5xx" {
  alarm_name          = "needu-${var.environment}-ai-deployment-5xx"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  datapoints_to_alarm = 2
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Sum"
  threshold           = var.deployment_5xx_threshold
  treat_missing_data  = "notBreaching"
  dimensions = {
    TargetDiscoveryName = "ai"
    ServiceName         = "needu-${var.environment}-ai"
    ClusterName         = aws_ecs_cluster.main.name
  }
  alarm_actions = var.alarm_sns_topic_arn == "" ? [] : [var.alarm_sns_topic_arn]
}

resource "aws_cloudwatch_log_group" "batch" {
  for_each          = local.catalog_jobs
  name              = "/needu/${var.environment}/batch/${each.key}"
  retention_in_days = 30
}
resource "aws_ecs_task_definition" "batch" {
  for_each                 = local.catalog_jobs
  family                   = "needu-${var.environment}-${each.key}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.task_cpu["ai"])
  memory                   = tostring(var.task_memory["ai"])
  execution_role_arn       = aws_iam_role.service_execution[each.key].arn
  task_role_arn            = aws_iam_role.catalog_task[each.key].arn
  container_definitions = jsonencode([
    merge({
      name             = each.key
      image            = "${var.ecr_repository_urls["ai"]}:${var.image_tags["ai"]}"
      essential        = true
      environment      = [for k, v in each.value.environment : { name = k, value = v }]
      secrets          = [for k, v in each.value.secrets : { name = k, valueFrom = v }]
      logConfiguration = { logDriver = "awslogs", options = { "awslogs-group" = aws_cloudwatch_log_group.batch[each.key].name, "awslogs-region" = "ap-northeast-2", "awslogs-stream-prefix" = "batch" } }
      }, length(lookup(var.catalog_commands, each.key, [])) == 0 ? {} : {
      command = var.catalog_commands[each.key]
    })
  ])
}
