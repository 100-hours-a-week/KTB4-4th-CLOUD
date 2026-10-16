module "monitoring_grafana" {
  source = "../../modules/monitoring-grafana"

  workspace_name = "needu-v2-monitoring"
}

output "grafana_workspace_id" {
  value = module.monitoring_grafana.workspace_id
}

output "grafana_workspace_endpoint" {
  value = module.monitoring_grafana.workspace_endpoint
}