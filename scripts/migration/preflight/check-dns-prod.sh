#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_prod_common.sh"
for v in HOSTED_ZONE_ID LIVE_HOST PROD_HOST V1_EIP V1_INSTANCE_ID ALB_NAME; do need "$v" DNS; done
records="$(aws route53 list-resource-record-sets --hosted-zone-id "$HOSTED_ZONE_ID" --output json)" || fail DNS 'Route 53 lookup failed'
actual_ip="$(jq -r --arg name "${LIVE_HOST}." '[.ResourceRecordSets[] | select(.Name==$name and .Type=="A") | .ResourceRecords[]?.Value] | join(",")' <<< "$records")"
[[ "$actual_ip" == "$V1_EIP" ]] || fail DNS "Current live A record differs from expected V1 EIP: $actual_ip"
prod_alias="$(jq -r --arg name "${PROD_HOST}." '[.ResourceRecordSets[] | select(.Name==$name and .Type=="A") | .AliasTarget.DNSName // empty] | first // empty' <<< "$records")"
alb_dns="$(aws elbv2 describe-load-balancers --names "$ALB_NAME" --query 'LoadBalancers[0].DNSName' --output text)" || fail DNS 'Prod ALB lookup failed'
[[ "${prod_alias%.}" == "${alb_dns%.}" ]] || fail DNS "Prod alias mismatch: ${prod_alias:-missing}"
eip_instance="$(aws ec2 describe-addresses --filters "Name=public-ip,Values=$V1_EIP" --query 'Addresses[0].InstanceId' --output text)" || fail DNS 'EIP lookup failed'
[[ "$eip_instance" == "$V1_INSTANCE_ID" ]] || fail DNS "EIP attached to unexpected instance: $eip_instance"
jq -n --arg live "$actual_ip" --arg prod "$prod_alias" --arg alb "$alb_dns" '{live_v1_ip:$live,prod_alias:$prod,alb_dns:$alb}' > "$PREFLIGHT_RESULT_DIR/dns.json"
pass DNS "Live A=$actual_ip; prod Alias=$prod_alias; EIP instance=$eip_instance"
