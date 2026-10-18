#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/prod-common.sh"
: "${DNS_PRESWITCH_APPROVED:?DNS_PRESWITCH_APPROVED is required}"
[[ "$DNS_PRESWITCH_APPROVED" == YES ]] || die 'Explicit DNS pre-switch approval required'
require_account

alb="$(aws elbv2 describe-load-balancers --names "$PROD_ALB_NAME" --output json)"
alb_dns="$(jq -r '.LoadBalancers[0].DNSName' <<< "$alb")"
alb_zone="$(jq -r '.LoadBalancers[0].CanonicalHostedZoneId' <<< "$alb")"
listener="$(aws elbv2 describe-listeners --load-balancer-arn "$(jq -r '.LoadBalancers[0].LoadBalancerArn' <<< "$alb")" --query 'Listeners[?Port==`443`].ListenerArn | [0]' --output text)"
rules="$(aws elbv2 describe-rules --listener-arn "$listener")"
v1_arn="$(aws elbv2 describe-target-groups --names needu-prod-v1 --query 'TargetGroups[0].TargetGroupArn' --output text)"

for priority in 5 20; do
  jq -e --arg p "$priority" --arg v1 "$v1_arn" '[.Rules[] | select(.Priority==$p) | .Actions[0].ForwardConfig.TargetGroups[] | select(.Weight==100 and .TargetGroupArn==$v1)] | length==1' <<< "$rules" >/dev/null \
    || die "Priority $priority is not V1=100"
done
jq -e '[.Rules[] | select(.Priority=="1" or .Priority=="2")] | length==0' <<< "$rules" >/dev/null || die 'Write Gate must be OFF during DNS pre-switch'
healthy="$(aws elbv2 describe-target-health --target-group-arn "$v1_arn" --query 'length(TargetHealthDescriptions[?TargetHealth.State==`healthy`])' --output text)"
(( healthy >= 1 )) || die 'V1 target group has no healthy target'

current="$(get_record "$LIVE_HOST")"
require_single_record "$current"
printf '%s\n' "$current" > "$EVIDENCE_DIR/dns-before.json"
if jq -e --arg dns "$alb_dns" '(.AliasTarget.DNSName // "" | rtrimstr("."))==$dns' <<< "$current" >/dev/null; then
  log "$LIVE_HOST is already the Prod ALB Alias"
  exit 0
fi
jq -e --arg ip "$V1_EIP" '.ResourceRecords==[{"Value":$ip}]' <<< "$current" >/dev/null || die 'Live DNS is neither the approved V1 EIP nor the Prod ALB'

change="$(jq -cn --arg name "$LIVE_HOST" --arg dns "$alb_dns" --arg zone "$alb_zone" '{Changes:[{Action:"UPSERT",ResourceRecordSet:{Name:$name,Type:"A",AliasTarget:{HostedZoneId:$zone,DNSName:$dns,EvaluateTargetHealth:true}}}]}')"
change_id="$(aws route53 change-resource-record-sets --hosted-zone-id "$HOSTED_ZONE_ID" --change-batch "$change" --query 'ChangeInfo.Id' --output text)"
aws route53 wait resource-record-sets-changed --id "$change_id"
after="$(get_record "$LIVE_HOST")"
jq -e --arg dns "$alb_dns" --arg zone "$alb_zone" '(.AliasTarget.DNSName|rtrimstr("."))==$dns and .AliasTarget.HostedZoneId==$zone' <<< "$after" >/dev/null || die 'DNS pre-switch verification failed'
printf '%s\n' "$after" > "$EVIDENCE_DIR/dns-after.json"
log "$LIVE_HOST pre-switched to Prod ALB while ALB remains V1=100"
