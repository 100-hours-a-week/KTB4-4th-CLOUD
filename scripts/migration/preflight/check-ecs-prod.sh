#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_prod_common.sh"
for v in ECS_CLUSTER ECS_SERVICE_PREFIX EXPECTED_TASK_COUNT; do need "$v" ECS; done
[[ "$EXPECTED_TASK_COUNT" =~ ^[1-9][0-9]*$ ]] || fail ECS 'Expected task count must be >=1'
for component in frontend backend ai; do
  name="${ECS_SERVICE_PREFIX}-${component}"
  json="$(aws ecs describe-services --cluster "$ECS_CLUSTER" --services "$name" --output json)" || fail ECS "$name lookup failed"
  jq -e --argjson n "$EXPECTED_TASK_COUNT" '.failures | length==0' <<< "$json" >/dev/null || fail ECS "$name service missing"
  jq -e --argjson n "$EXPECTED_TASK_COUNT" '.services[0] | .status=="ACTIVE" and .desiredCount >= $n and .runningCount >= $n and .pendingCount==0 and ([.deployments[] | select(.status=="PRIMARY" and .rolloutState=="COMPLETED")] | length)==1' <<< "$json" >/dev/null || fail ECS "$name tasks not ready (expected >=$EXPECTED_TASK_COUNT)"
  while IFS= read -r tg; do
    [[ -n "$tg" ]] || continue
    health="$(aws elbv2 describe-target-health --target-group-arn "$tg" --output json)" || fail ECS "$name TG lookup failed"
    jq -e --argjson n "$EXPECTED_TASK_COUNT" '([.TargetHealthDescriptions[] | select(.TargetHealth.State=="healthy")] | length) >= $n and ([.TargetHealthDescriptions[] | select(.TargetHealth.State!="healthy")] | length)==0' <<< "$health" >/dev/null || fail ECS "$name target health failed"
  done < <(jq -r '.services[0].loadBalancers[]?.targetGroupArn' <<< "$json")
  if [[ "$component" != ai ]]; then
    jq -e '.services[0].loadBalancers | length>0' <<< "$json" >/dev/null || fail ECS "$name missing ALB target group"
  fi
done
pass ECS "FE/BE/AI running >=$EXPECTED_TASK_COUNT and ALB targets healthy"
