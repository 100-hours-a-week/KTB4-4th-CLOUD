resource "aws_prometheus_rule_group_namespace" "prod" {
  name         = "needu-v3-prod-alert-rules"
  workspace_id = aws_prometheus_workspace.prod.id

  data = <<-YAML
    groups:
      - name: needu-v3-prod-kubernetes-health
        interval: 1m
        rules:
          - alert: KubernetesNodeNotReady
            expr: kube_node_status_condition{condition="Ready",status="true"} == 0
            for: 5m
            labels:
              severity: critical
            annotations:
              summary: 'Kubernetes node is NotReady'
              metric: 'Node readiness'
              description: 'A Production EKS node has not been Ready for at least five minutes.'
              first_check: 'Run kubectl get nodes -o wide and inspect the affected node events.'
              response_guide: 'Check node-group health, EC2 capacity, kubelet status and cluster autoscaler logs.'
          - alert: KubernetesDeploymentReplicasUnavailable
            expr: kube_deployment_status_replicas_unavailable > 0
            for: 5m
            labels:
              severity: warning
            annotations:
              summary: 'Deployment replicas are unavailable'
              metric: 'Unavailable Deployment replicas'
              description: 'A Production Deployment has one or more unavailable replicas for at least five minutes.'
              first_check: 'Run kubectl get deployments -A and inspect the affected Deployment and Pods.'
              response_guide: 'Check Pod events, image pulls, resource requests, probes and recent rollout history.'
          - alert: KubernetesPodCrashLoopBackOff
            expr: kube_pod_container_status_waiting_reason{reason="CrashLoopBackOff"} > 0
            for: 5m
            labels:
              severity: warning
            annotations:
              summary: 'Pod container is crash looping'
              metric: 'CrashLoopBackOff'
              description: 'A Production Pod container has remained in CrashLoopBackOff for at least five minutes.'
              first_check: 'Run kubectl get pods -A and kubectl logs for the affected Pod.'
              response_guide: 'Inspect current and previous container logs, Secret synchronization and recent image changes.'
  YAML
}