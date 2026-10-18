#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_prod_common.sh"
for v in ALB_NAME FRONTEND_TARGET_GROUP BACKEND_TARGET_GROUP PROD_HOST; do need "$v" ALB; done
alb="$(aws elbv2 describe-load-balancers --names "$ALB_NAME" --query 'LoadBalancers[0].LoadBalancerArn' --output text)" || fail ALB 'ALB not found'
listener="$(aws elbv2 describe-listeners --load-balancer-arn "$alb" --query 'Listeners[?Port==`443`].ListenerArn | [0]' --output text)" || fail ALB 'Listener lookup failed'
[[ "$listener" != None && -n "$listener" ]] || fail ALB 'HTTPS 443 listener missing'
rules="$(aws elbv2 describe-rules --listener-arn "$listener" --output json)" || fail ALB 'Rules lookup failed'
fe="$(aws elbv2 describe-target-groups --names "$FRONTEND_TARGET_GROUP" --query 'TargetGroups[0].TargetGroupArn' --output text)" || fail ALB 'FE TG missing'
be="$(aws elbv2 describe-target-groups --names "$BACKEND_TARGET_GROUP" --query 'TargetGroups[0].TargetGroupArn' --output text)" || fail ALB 'BE TG missing'
# Rule priority 10 is specifically scoped to prod.needu.gift + /api/v1/*.
jq -e --arg host "$PROD_HOST" --arg be "$be" '
  [.Rules[] | select(.Priority=="10") | select(
    ([.Conditions[] | select(.Field=="host-header") | .HostHeaderConfig.Values[]] | index($host)) != null and
    ([.Conditions[] | select(.Field=="path-pattern") | .PathPatternConfig.Values[]] | index("/api/v1/*")) != null and
    ([.Actions[] | select(.Type=="forward") | .ForwardConfig.TargetGroups[] | select(.TargetGroupArn==$be and .Weight>0)] | length)==1
  )] | length==1' <<< "$rules" >/dev/null || fail ALB 'Prod API rule priority 10 invalid'
jq -e --arg fe "$fe" '
  [.Rules[] | select(.Priority=="default") | select(
    ([.Actions[] | select(.Type=="forward") | .ForwardConfig.TargetGroups[] | select(.TargetGroupArn==$fe and .Weight>0)] | length)==1
  )] | length==1' <<< "$rules" >/dev/null || fail ALB 'Prod default FE rule invalid'
# Fail if a migration write gate is unexpectedly installed at reserved priorities.
jq -e '[.Rules[] | select(.Priority=="1" or .Priority=="2")] | length==0' <<< "$rules" >/dev/null || fail ALB 'Reserved write-gate rule already present'
printf '%s\n' "$rules" > "$PREFLIGHT_RESULT_DIR/alb-rules.json"
pass ALB 'Prod host API priority=10, default FE, no reserved gate'
