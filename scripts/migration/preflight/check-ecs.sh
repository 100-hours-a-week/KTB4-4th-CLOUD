#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "$0")/../common/common.sh"
for component in frontend backend ai; do
  service="needu-staging-$component"; json="$(aws ecs describe-services --cluster "$ECS_CLUSTER" --services "$service")"
  require_equal "$service desired count" 2 "$(jq -r '.services[0].desiredCount' <<<"$json")"
  require_equal "$service running count" 2 "$(jq -r '.services[0].runningCount' <<<"$json")"
  require_equal "$service pending count" 0 "$(jq -r '.services[0].pendingCount' <<<"$json")"
  require_equal "$service deployment" COMPLETED "$(jq -r '.services[0].deployments[] | select(.status == "PRIMARY") | .rolloutState' <<<"$json")"
  while IFS= read -r tg; do
    [[ -n "$tg" ]] || continue; health="$(aws elbv2 describe-target-health --target-group-arn "$tg")"
    require_equal "$service healthy targets" 2 "$(jq '[.TargetHealthDescriptions[] | select(.TargetHealth.State == "healthy")] | length' <<<"$health")"
    require_equal "$service unhealthy targets" 0 "$(jq '[.TargetHealthDescriptions[] | select(.TargetHealth.State != "healthy")] | length' <<<"$health")"
  done < <(jq -r '.services[0].loadBalancers[].targetGroupArn' <<<"$json")
done
