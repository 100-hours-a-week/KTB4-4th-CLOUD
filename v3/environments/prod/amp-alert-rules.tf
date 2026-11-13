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
      - name: needu-v3-prod-ai-reply-worker
        interval: 1m
        rules:
          - alert: AIReplyQueueProcessingStalled
            expr: max(aichat_reply_queue_length) > 0 and on() sum(rate(aichat_reply_jobs_processed_total[5m])) == 0
            for: 5m
            labels:
              severity: critical
              service: ai-worker
            annotations:
              summary: 'AI reply queue processing has stalled'
              metric: 'Queue length and processed job rate'
              description: 'The AI reply queue contains work, but no job has completed during the last five minutes.'
              first_check: 'Check the ai-worker Pod status, logs and Redis Stream connectivity.'
              response_guide: 'Verify Worker consumer activity, ai-fastapi availability, Stream pending entries and application-node capacity.'
          - alert: AIReplyQueueOldestWaitHigh
            expr: max(aichat_reply_queue_oldest_wait_seconds) > 60
            for: 5m
            labels:
              severity: warning
              service: ai-worker
            annotations:
              summary: 'AI reply queue wait time is high'
              metric: 'Oldest queued job wait time'
              description: 'The oldest AI reply job has waited longer than 60 seconds for at least five minutes.'
              first_check: 'Compare queue length, pending count, processing latency and Worker replica health.'
              response_guide: 'Check downstream AI latency, Worker saturation, concurrency permits and whether scaling is required.'
          - alert: AIReplyQueueRejected
            expr: sum(increase(aichat_reply_queue_rejected_total[5m])) > 0
            for: 1m
            labels:
              severity: warning
              service: ai-worker
            annotations:
              summary: 'AI reply queue rejected a request'
              metric: 'Rejected queue requests'
              description: 'At least one AI reply request was rejected while entering the queue during the last five minutes.'
              first_check: 'Check API logs and queue capacity metrics around the alert time.'
              response_guide: 'Inspect admission limits, Redis availability and sudden request-volume changes.'
          - alert: AIReplyJobGaveUp
            expr: sum(increase(aichat_reply_jobs_gave_up_total[5m])) > 0
            for: 1m
            labels:
              severity: critical
              service: ai-worker
            annotations:
              summary: 'AI reply job exhausted retries'
              metric: 'Jobs that gave up'
              description: 'At least one AI reply job exhausted its retry policy during the last five minutes.'
              first_check: 'Find the corresponding Worker error and retry logs.'
              response_guide: 'Check ai-fastapi and external model availability, Redis health and whether the failed job needs recovery.'
          - alert: AIReplyJobFailureRateHigh
            expr: >-
              sum(increase(aichat_reply_jobs_processed_total[5m])) >= 5
              and on()
              (
                sum(increase(aichat_reply_jobs_processed_total{result=~"retryable_failure|terminal_failure"}[5m]))
                /
                sum(increase(aichat_reply_jobs_processed_total[5m]))
              ) > 0.2
            for: 5m
            labels:
              severity: warning
              service: ai-worker
            annotations:
              summary: 'AI reply job failure rate is high'
              metric: 'Failed job ratio'
              description: 'More than 20 percent of at least five recently processed AI reply jobs failed for five minutes.'
              first_check: 'Compare retryable and terminal failures with processing latency and Worker logs.'
              response_guide: 'Identify whether failures originate in the Worker, ai-fastapi, external model endpoint or Redis.'
  YAML
}
