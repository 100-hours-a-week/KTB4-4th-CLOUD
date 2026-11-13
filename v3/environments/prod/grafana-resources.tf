resource "grafana_data_source" "prod_amp" {
  name        = "NeedU V3 Production AMP"
  uid         = "needu-v3-prod-amp"
  type        = "prometheus"
  url         = trimsuffix(aws_prometheus_workspace.prod.prometheus_endpoint, "/")
  access_mode = "proxy"
  is_default  = true
  json_data_encoded = jsonencode({
    httpMethod    = "POST"
    sigV4Auth     = true
    sigV4AuthType = "default"
    sigV4Region   = var.aws_region
    sigv4Service  = "aps"
  })
}

resource "grafana_dashboard" "prod_kubernetes_overview" {
  config_json = file("${path.module}/grafana/dashboards/needu-v3-prod-kubernetes-overview.json")
  overwrite   = true

  depends_on = [grafana_data_source.prod_amp]
}
