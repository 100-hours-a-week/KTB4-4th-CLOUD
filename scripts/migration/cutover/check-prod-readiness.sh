#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/prod-common.sh"
require_account
: "${ECS_CLUSTER:?ECS_CLUSTER required}"
: "${FE_SERVICE:?FE_SERVICE required}"
: "${BE_SERVICE:?BE_SERVICE required}"
EXPECTED_TASK_COUNT="${EXPECTED_TASK_COUNT:-2}"
[[ "$EXPECTED_TASK_COUNT" =~ ^[1-9][0-9]*$ ]] || die 'Invalid EXPECTED_TASK_COUNT'
[[ "$LIVE_HOST" == needu.gift && "$PROD_HOST" == prod.needu.gift ]] || die 'Unexpected hosts'
[[ "$PROD_ALB_NAME" == needu-prod-alb ]] || die 'Unexpected ALB'
mkdir -p "$EVIDENCE_DIR"
alb_info="$(aws elbv2 describe-load-balancers --names "$PROD_ALB_NAME" --output json)" || die 'ALB lookup failed'
alb_arn="$(jq -r '.LoadBalancers[0].LoadBalancerArn // empty' <<< "$alb_info")"
alb_dns="$(jq -r '.LoadBalancers[0].DNSName // empty' <<< "$alb_info")"
alb_zone="$(jq -r '.LoadBalancers[0].CanonicalHostedZoneId // empty' <<< "$alb_info")"
[[ -n "$alb_arn" && -n "$alb_dns" && -n "$alb_zone" && "$alb_dns" == "${PROD_ALB_DNS%.}" ]] || die 'ALB metadata mismatch'
for host in "$LIVE_HOST" "$PROD_HOST"; do
  record="$(get_record "$host")"
  require_single_record "$record"
  jq -e --arg dns "$alb_dns" --arg zone "$alb_zone" '(.AliasTarget.DNSName // "" | rtrimstr(".")) == $dns and .AliasTarget.HostedZoneId == $zone' <<< "$record" >/dev/null || die "$host is not Prod ALB Alias"
  printf '%s\n' "$record" > "$EVIDENCE_DIR/dns-${host}.json"
done
log 'DNS After state verified'
listener="$(aws elbv2 describe-listeners --load-balancer-arn "$alb_arn" --query 'Listeners[?Port==`443`].ListenerArn | [0]' --output text)"
[[ -n "$listener" && "$listener" != None ]] || die 'HTTPS listener missing'
rules="$(aws elbv2 describe-rules --listener-arn "$listener" --output json)"
printf '%s\n' "$rules" > "$EVIDENCE_DIR/alb-rules-readiness.json"
tg_arn() {
  local arn
  arn="$(aws elbv2 describe-target-groups --names "$1" --query 'TargetGroups[0].TargetGroupArn' --output text)" || die "Target group lookup failed: $1"
  [[ -n "$arn" && "$arn" != None ]] || die "Target group missing: $1"
  printf '%s' "$arn"
}
v1_arn="$(tg_arn needu-prod-v1)"
fe_arn="$(tg_arn needu-prod-fe)"
be_arn="$(tg_arn needu-prod-be)"
check_rule() {
  local priority="$1" path="$2" v2="$3" matched
  matched="$(jq -r --arg priority "$priority" --arg path "$path" --arg live "$LIVE_HOST" --arg prod "$PROD_HOST" --arg v1 "$v1_arn" --arg v2 "$v2" '
    [.Rules[] | select(.Priority==$priority)
     | select(([.Conditions[] | select(.Field=="host-header") | .Values[]]) as $hosts | ($hosts|index($live)) != null and ($hosts|index($prod)) != null)
     | select(([.Conditions[] | select(.Field=="path-pattern") | .Values[]]) as $paths | ($paths|index($path)) != null)
     | .Actions[] | select(.Type=="forward") | .ForwardConfig.TargetGroups
     | select(length==2)
     | select(any(.[]; .TargetGroupArn==$v1 and .Weight==100))
     | select(any(.[]; .TargetGroupArn==$v2 and .Weight==0))] | length' <<< "$rules")" || die "Rule $priority jq failed"
  [[ "$matched" == 1 ]] || die "Priority $priority not V1=100/V2=0"
}
check_rule 5 '/api/v1/*' "$be_arn"
check_rule 20 '/*' "$fe_arn"
jq -e '[.Rules[] | select(.Priority=="1" or .Priority=="2")] | length==0' <<< "$rules" >/dev/null || die 'Gate is active; pre-freeze readiness requires disabled gate'
log 'ALB V1=100, V2=0 and gate disabled verified'
check_health() {
  local name="$1" arn="$2" health count
  health="$(aws elbv2 describe-target-health --target-group-arn "$arn" --output json)" || die "Target health failed: $name"
  printf '%s\n' "$health" > "$EVIDENCE_DIR/health-${name}.json"
  count="$(jq '[.TargetHealthDescriptions[] | select(.TargetHealth.State=="healthy")] | length' <<< "$health")"
  (( count >= 1 )) || die "$name has no healthy targets"
  log "$name healthy=$count"
}
check_health needu-prod-v1 "$v1_arn"
check_health needu-prod-fe "$fe_arn"
check_health needu-prod-be "$be_arn"
check_service() {
  local service="$1" result
  result="$(aws ecs describe-services --cluster "$ECS_CLUSTER" --services "$service" --output json)" || die "ECS lookup failed: $service"
  printf '%s\n' "$result" > "$EVIDENCE_DIR/ecs-${service}.json"
  jq -e --argjson min "$EXPECTED_TASK_COUNT" '(.failures|length)==0 and (.services|length)==1 and .services[0].status=="ACTIVE" and .services[0].runningCount >= $min and .services[0].desiredCount >= $min and .services[0].runningCount == .services[0].desiredCount and .services[0].pendingCount==0' <<< "$result" >/dev/null || die "ECS not ready: $service"
  log "ECS ready: $service"
}
check_service "$FE_SERVICE"
check_service "$BE_SERVICE"
log 'PRE-FREEZE readiness PASS (not final cutover approval)'
