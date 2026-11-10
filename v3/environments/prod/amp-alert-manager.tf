data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "prod_amp_sns" {
  statement {
    sid       = "AllowAccountTopicAdministration"
    effect    = "Allow"
    actions   = ["sns:*"]
    resources = [aws_sns_topic.prod_alerts.arn]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  statement {
    sid       = "AllowProdAMPToPublishAlerts"
    effect    = "Allow"
    actions   = ["sns:Publish", "sns:GetTopicAttributes"]
    resources = [aws_sns_topic.prod_alerts.arn]

    principals {
      type        = "Service"
      identifiers = ["aps.amazonaws.com"]
    }

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_prometheus_workspace.prod.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_sns_topic_policy" "prod_amp" {
  arn    = aws_sns_topic.prod_alerts.arn
  policy = data.aws_iam_policy_document.prod_amp_sns.json
}

resource "aws_prometheus_alert_manager_definition" "prod" {
  workspace_id = aws_prometheus_workspace.prod.id

  definition = <<-YAML
    alertmanager_config: |
      global:
        resolve_timeout: 5m
      templates:
        - default_template
      route:
        receiver: needu-prod-discord
        group_by: [alertname, namespace, deployment, node, pod]
        group_wait: 30s
        group_interval: 5m
        repeat_interval: 4h
      receivers:
        - name: needu-prod-discord
          sns_configs:
            - sigv4:
                region: ${var.aws_region}
              topic_arn: ${aws_sns_topic.prod_alerts.arn}
              subject: '[NeedU V3 Prod] {{ .Status | toUpper }} {{ .CommonLabels.alertname }}'
              message: '{{ template "sns.default.message" . }}'
    template_files:
      default_template: |
        {{ define "sns.default.message" }}{{ "{" }}"receiver": "{{ .Receiver }}","status": "{{ .Status }}","alerts": [{{ range $alertIndex, $alerts := .Alerts }}{{ if $alertIndex }}, {{ end }}{{ "{" }}"status": "{{ $alerts.Status }}"{{ if gt (len $alerts.Labels.SortedPairs) 0 -}},"labels": {{ "{" }}{{ range $index, $label := $alerts.Labels.SortedPairs }}{{ if $index }}, {{ end }}"{{ $label.Name }}": "{{ $label.Value }}"{{ end }}{{ "}" }}{{- end }}{{ if gt (len $alerts.Annotations.SortedPairs) 0 -}},"annotations": {{ "{" }}{{ range $index, $annotations := $alerts.Annotations.SortedPairs }}{{ if $index }}, {{ end }}"{{ $annotations.Name }}": "{{ $annotations.Value }}"{{ end }}{{ "}" }}{{- end }},"startsAt": "{{ $alerts.StartsAt }}","endsAt": "{{ $alerts.EndsAt }}","generatorURL": "{{ $alerts.GeneratorURL }}","fingerprint": "{{ $alerts.Fingerprint }}"{{ "}" }}{{ end }}]{{ if gt (len .GroupLabels) 0 -}},"groupLabels": {{ "{" }}{{ range $index, $groupLabels := .GroupLabels.SortedPairs }}{{ if $index }}, {{ end }}"{{ $groupLabels.Name }}": "{{ $groupLabels.Value }}"{{ end }}{{ "}" }}{{- end }}{{ if gt (len .CommonLabels) 0 -}},"commonLabels": {{ "{" }}{{ range $index, $commonLabels := .CommonLabels.SortedPairs }}{{ if $index }}, {{ end }}"{{ $commonLabels.Name }}": "{{ $commonLabels.Value }}"{{ end }}{{ "}" }}{{- end }}{{ if gt (len .CommonAnnotations) 0 -}},"commonAnnotations": {{ "{" }}{{ range $index, $commonAnnotations := .CommonAnnotations.SortedPairs }}{{ if $index }}, {{ end }}"{{ $commonAnnotations.Name }}": "{{ $commonAnnotations.Value }}"{{ end }}{{ "}" }}{{- end }}{{ "}" }}{{ end }}
        {{ define "sns.default.subject" }}[{{ .Status | toUpper }}{{ if eq .Status "firing" }}:{{ .Alerts.Firing | len }}{{ end }}]{{ end }}
  YAML

  depends_on = [aws_sns_topic_policy.prod_amp]
}
