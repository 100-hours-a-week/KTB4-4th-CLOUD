#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "$0")/../common/common.sh"
alb_arn="$(aws elbv2 describe-load-balancers --names "$ALB_NAME" --query 'LoadBalancers[0].LoadBalancerArn' --output text 2>/dev/null || true)"
listener_arn="$(aws elbv2 describe-listeners --load-balancer-arn "$alb_arn" --query 'Listeners[?Port==`443`].ListenerArn | [0]' --output text 2>/dev/null || true)"
require_nonempty "ALB HTTPS Listener" "$listener_arn"
[[ -n "$listener_arn" && "$listener_arn" != None ]] || exit 0
rules_json="$(aws elbv2 describe-rules --listener-arn "$listener_arn")"
require_equal "Write Gate disabled" 0 "$(jq '[.Rules[] | select(.Priority == "1" or .Priority == "2")] | length' <<<"$rules_json")"
v1_arn="$(aws elbv2 describe-target-groups --names "$V1_TARGET_GROUP" --query 'TargetGroups[0].TargetGroupArn' --output text)"
frontend_arn="$(aws elbv2 describe-target-groups --names "$FRONTEND_TARGET_GROUP" --query 'TargetGroups[0].TargetGroupArn' --output text)"
backend_arn="$(aws elbv2 describe-target-groups --names "$BACKEND_TARGET_GROUP" --query 'TargetGroups[0].TargetGroupArn' --output text)"
weight() { jq -r --arg priority "$1" --arg target "$2" '.Rules[] | select(.Priority == $priority) | .Actions[] | select(.Type == "forward") | .ForwardConfig.TargetGroups[] | select(.TargetGroupArn == $target) | .Weight' <<<"$rules_json"; }
require_equal "Frontend rule V1 weight" 100 "$(weight "$FRONTEND_RULE_PRIORITY" "$v1_arn")"
require_equal "Frontend rule V2 weight" 0 "$(weight "$FRONTEND_RULE_PRIORITY" "$frontend_arn")"
require_equal "API rule V1 weight" 100 "$(weight "$API_RULE_PRIORITY" "$v1_arn")"
require_equal "API rule V2 weight" 0 "$(weight "$API_RULE_PRIORITY" "$backend_arn")"
jq -n --arg listener "$listener_arn" --arg v1 "$v1_arn" --arg frontend "$frontend_arn" --arg backend "$backend_arn" '{listener_arn:$listener,v1_target_group_arn:$v1,frontend_target_group_arn:$frontend,backend_target_group_arn:$backend}' > "$PREFLIGHT_RESULT_DIR/alb.json"
