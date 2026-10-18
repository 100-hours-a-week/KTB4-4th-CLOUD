# 기존 Prod Auto Scaling Target을 유지한 채 Runtime Control 관리 주소로 이전합니다.
moved {
  from = module.v2.aws_appautoscaling_target.ecs["frontend"]
  to   = module.v2.aws_appautoscaling_target.ecs_runtime_controlled["frontend"]
}

moved {
  from = module.v2.aws_appautoscaling_target.ecs["backend"]
  to   = module.v2.aws_appautoscaling_target.ecs_runtime_controlled["backend"]
}

moved {
  from = module.v2.aws_appautoscaling_target.ecs["ai"]
  to   = module.v2.aws_appautoscaling_target.ecs_runtime_controlled["ai"]
}
