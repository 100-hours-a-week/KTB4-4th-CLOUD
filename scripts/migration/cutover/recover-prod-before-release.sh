#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/prod-common.sh"
log 'Starting automatic pre-release recovery: ALB -> V1, then Write Gate OFF'
ALLOW_RECOVERY_WITHOUT_GATE=YES CUTOVER_TARGET=v1 bash scripts/migration/cutover/switch-alb-prod.sh

v1_tg_arn="$(aws elbv2 describe-target-groups \
  --names needu-prod-v1 \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text)"
[[ -n "$v1_tg_arn" && "$v1_tg_arn" != None ]] || die 'Could not resolve the V1 target group; Write Gate remains enabled'

v1_health="$(aws elbv2 describe-target-health --target-group-arn "$v1_tg_arn" --output json)"
printf '%s\n' "$v1_health" > "$EVIDENCE_DIR/v1-target-health-after-recovery.json"
healthy_count="$(jq '[.TargetHealthDescriptions[] | select(.TargetHealth.State == "healthy")] | length' <<< "$v1_health")"
if (( healthy_count < 1 )); then
  die "V1 target group has no healthy targets; Write Gate remains enabled (target group: $v1_tg_arn)"
fi
log "V1 target health verified: healthy targets=$healthy_count"

GATE_ACTION=disable bash scripts/migration/cutover/manage-write-gate-prod.sh
log 'Recovery completed. DMS remains stopped and must not be restarted without a data recovery decision.'
