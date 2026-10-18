#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/prod-common.sh"
require_account
[[ "$LIVE_HOST" == needu.gift && "$PROD_HOST" == prod.needu.gift ]] || die 'Unexpected host configuration'
[[ "$PROD_ALB_NAME" == needu-prod-alb ]] || die 'Unexpected ALB name'
current="$(get_record "$LIVE_HOST")"
require_single_record "$current"
jq -e --arg ip "$V1_EIP" '.TTL == 300 and .ResourceRecords == [{"Value":$ip}] and (has("AliasTarget")|not)' <<< "$current" >/dev/null \
  || die 'Live DNS no longer matches expected V1 EIP/TTL=300; stop and review'
prod="$(get_record "$PROD_HOST")"
require_single_record "$prod"
jq -e --arg dns "$PROD_ALB_DNS" '(.AliasTarget.DNSName|rtrimstr(".")) == $dns' <<< "$prod" >/dev/null \
  || die 'Prod alias target differs from expected ALB'
zone="$(aws elbv2 describe-load-balancers --names "$PROD_ALB_NAME" --query 'LoadBalancers[0].CanonicalHostedZoneId' --output text)"
[[ "$zone" != None && -n "$zone" ]] || die 'ALB canonical hosted zone missing'
printf '%s\n' "$zone" > "$EVIDENCE_DIR/alb-zone-id.txt"
printf '%s\n' "$current" > "$EVIDENCE_DIR/live-before.json"
printf '%s\n' "$prod" > "$EVIDENCE_DIR/prod-alias-before.json"
log 'Live V1 A record and Prod ALB alias match expected state'
# Explicitly validate live-host API routing (priority 10 only matches prod.needu.gift currently).
alb_arn="$(aws elbv2 describe-load-balancers --names "$PROD_ALB_NAME" --query 'LoadBalancers[0].LoadBalancerArn' --output text)"
listener="$(aws elbv2 describe-listeners --load-balancer-arn "$alb_arn" --query 'Listeners[?Port==`443`].ListenerArn | [0]' --output text)"
[[ "$listener" != None && -n "$listener" ]] || die 'HTTPS listener missing'
rules="$(aws elbv2 describe-rules --listener-arn "$listener")"
backend_arn="$(aws elbv2 describe-target-groups --names needu-prod-be --query 'TargetGroups[0].TargetGroupArn' --output text)"
frontend_arn="$(aws elbv2 describe-target-groups --names needu-prod-fe --query 'TargetGroups[0].TargetGroupArn' --output text)"
# Require explicit needu.gift API path rule, rather than default FE fallback.
jq -e --arg host "$LIVE_HOST" --arg tg "$backend_arn" '
  [.Rules[] | select(.Priority!="default") |
   select(any(.Conditions[]; .Field=="host-header" and any(.Values[]?; .==$host))) |
   select(any(.Conditions[]; .Field=="path-pattern" and any(.Values[]?; .=="/api/v1/*"))) |
   select(any(.Actions[]; .Type=="forward" and
     ((.TargetGroupArn?==$tg) or any(.ForwardConfig.TargetGroups[]?; .TargetGroupArn==$tg))))] | length >= 1
' <<< "$rules" >/dev/null || die 'Missing explicit needu.gift /api/v1/* -> Prod backend rule'
jq -e --arg tg "$frontend_arn" '[.Rules[] | select(.Priority=="default") | .Actions[] | select(.Type=="forward") | select((.TargetGroupArn?==$tg) or any(.ForwardConfig.TargetGroups[]?; .TargetGroupArn==$tg))] | length==1' <<< "$rules" >/dev/null || die 'Frontend default route mismatch'
for name in needu-prod-fe needu-prod-be; do
  arn="$(aws elbv2 describe-target-groups --names "$name" --query 'TargetGroups[0].TargetGroupArn' --output text)"
  healthy="$(aws elbv2 describe-target-health --target-group-arn "$arn" --output json | jq '[.TargetHealthDescriptions[] | select(.TargetHealth.State=="healthy")] | length')"
  (( healthy >= 1 )) || die "$name has no healthy targets"
done
log 'ALB host routing and FE/BE healthy targets verified'
