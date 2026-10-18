#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/prod-common.sh"
: "${CUTOVER_TARGET:?CUTOVER_TARGET must be v1 or v2}"
[[ "$CUTOVER_TARGET" == v1 || "$CUTOVER_TARGET" == v2 ]] || die 'CUTOVER_TARGET must be v1 or v2'
require_account

alb_arn="$(aws elbv2 describe-load-balancers --names "$PROD_ALB_NAME" --query 'LoadBalancers[0].LoadBalancerArn' --output text)"
listener="$(aws elbv2 describe-listeners --load-balancer-arn "$alb_arn" --query 'Listeners[?Port==`443`].ListenerArn | [0]' --output text)"
rules="$(aws elbv2 describe-rules --listener-arn "$listener")"

if [[ "${ALLOW_RECOVERY_WITHOUT_GATE:-NO}" != YES ]]; then
  for priority in 1 2; do
    gate="$(jq -r --arg p "$priority" '.Rules[] | select(.Priority==$p) | .RuleArn' <<< "$rules")"
    [[ -n "$gate" ]] || die "Write Gate priority $priority is missing"
    purpose="$(aws elbv2 describe-tags --resource-arns "$gate" --query "TagDescriptions[0].Tags[?Key=='Purpose'].Value | [0]" --output text)"
    [[ "$purpose" == ProdMigrationWriteGate ]] || die "Write Gate priority $priority is not owned by this migration"
  done
elif [[ "$CUTOVER_TARGET" != v1 ]]; then
  die 'Gate bypass is permitted only for automatic V1 recovery'
fi

v1="$(aws elbv2 describe-target-groups --names needu-prod-v1 --query 'TargetGroups[0].TargetGroupArn' --output text)"
fe="$(aws elbv2 describe-target-groups --names needu-prod-fe --query 'TargetGroups[0].TargetGroupArn' --output text)"
be="$(aws elbv2 describe-target-groups --names needu-prod-be --query 'TargetGroups[0].TargetGroupArn' --output text)"

if [[ "$CUTOVER_TARGET" == v2 ]]; then
  for tg in "$fe" "$be"; do
    healthy="$(aws elbv2 describe-target-health --target-group-arn "$tg" --query 'length(TargetHealthDescriptions[?TargetHealth.State==`healthy`])' --output text)"
    (( healthy >= 1 )) || die "V2 target group has no healthy targets: $tg"
  done
  v1_weight=0
  v2_weight=100
else
  v1_weight=100
  v2_weight=0
fi

switch_rule() {
  local priority="$1" v2="$2" rule action actual
  rule="$(jq -r --arg p "$priority" '.Rules[] | select(.Priority==$p) | .RuleArn' <<< "$rules")"
  [[ -n "$rule" ]] || die "Routing rule priority $priority is missing"
  action="$(jq -cn --arg v1 "$v1" --arg v2 "$v2" --argjson w1 "$v1_weight" --argjson w2 "$v2_weight" \
    '[{Type:"forward",ForwardConfig:{TargetGroups:[{TargetGroupArn:$v1,Weight:$w1},{TargetGroupArn:$v2,Weight:$w2}]}}]')"
  aws elbv2 modify-rule --rule-arn "$rule" --actions "$action" >/dev/null
  actual="$(aws elbv2 describe-rules --rule-arns "$rule")"
  jq -e --arg v1 "$v1" --arg v2 "$v2" --argjson w1 "$v1_weight" --argjson w2 "$v2_weight" '
    .Rules[0].Actions[0].ForwardConfig.TargetGroups as $tg
    | any($tg[]; .TargetGroupArn==$v1 and .Weight==$w1)
      and any($tg[]; .TargetGroupArn==$v2 and .Weight==$w2)' <<< "$actual" >/dev/null \
    || die "Routing verification failed for priority $priority"
}

switch_rule 5 "$be"
switch_rule 20 "$fe"
log "Prod ALB routing switched to $CUTOVER_TARGET"
