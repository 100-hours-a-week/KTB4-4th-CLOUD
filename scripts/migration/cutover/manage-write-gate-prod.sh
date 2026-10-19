#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/prod-common.sh"

: "${GATE_ACTION:?GATE_ACTION must be enable, disable or status}"
: "${PROD_ALB_NAME:=needu-prod-alb}"

require_account

alb_arn="$(aws elbv2 describe-load-balancers --names "$PROD_ALB_NAME" --query 'LoadBalancers[0].LoadBalancerArn' --output text)"
listener_arn="$(aws elbv2 describe-listeners --load-balancer-arn "$alb_arn" --query 'Listeners[?Port==`443`].ListenerArn | [0]' --output text)"
[[ -n "$listener_arn" && "$listener_arn" != None ]] || die 'Prod HTTPS listener not found'

find_rule() {
  aws elbv2 describe-rules --listener-arn "$listener_arn" \
    --query "Rules[?Priority=='$1'].RuleArn | [0]" --output text
}

is_owned() {
  [[ "$(aws elbv2 describe-tags --resource-arns "$1" --query "TagDescriptions[0].Tags[?Key=='Purpose'].Value | [0]" --output text)" == ProdMigrationWriteGate ]]
}

method_rule="$(find_rule 1)"
callback_rule="$(find_rule 2)"

if [[ "$GATE_ACTION" == enable ]]; then
  for rule in "$method_rule" "$callback_rule"; do
    if [[ -n "$rule" && "$rule" != None ]] && ! is_owned "$rule"; then
      die "Reserved Write Gate priority is already used: $rule"
    fi
  done

  action="$(jq -cn '[{Type:"fixed-response",FixedResponseConfig:{MessageBody:"{\"code\":\"MIGRATION_IN_PROGRESS\"}",StatusCode:"503",ContentType:"application/json"}}]')"
  if [[ -z "$method_rule" || "$method_rule" == None ]]; then
    conditions="$(jq -cn '[
      {Field:"host-header",HostHeaderConfig:{RegexValues:["^(prod\\.)?needu\\.gift$"]}},
      {Field:"http-request-method",HttpRequestMethodConfig:{Values:["POST","PUT","PATCH","DELETE"]}}
    ]')"
    aws elbv2 create-rule --listener-arn "$listener_arn" --priority 1 \
      --conditions "$conditions" --actions "$action" \
      --tags Key=Purpose,Value=ProdMigrationWriteGate >/dev/null
  fi
  if [[ -z "$callback_rule" || "$callback_rule" == None ]]; then
    conditions="$(jq -cn '[
      {Field:"host-header",HostHeaderConfig:{Values:["needu.gift","prod.needu.gift"]}},
      {Field:"path-pattern",PathPatternConfig:{Values:["/api/v1/auth/csrf","/api/v1/auth/kakao/*","/api/v1/friends/kakao/*"]}}
    ]')"
    aws elbv2 create-rule --listener-arn "$listener_arn" --priority 2 \
      --conditions "$conditions" --actions "$action" \
      --tags Key=Purpose,Value=ProdMigrationWriteGate >/dev/null
  fi
elif [[ "$GATE_ACTION" == disable ]]; then
  for rule in "$method_rule" "$callback_rule"; do
    if [[ -n "$rule" && "$rule" != None ]]; then
      is_owned "$rule" || die "Refusing to delete unowned rule: $rule"
      aws elbv2 delete-rule --rule-arn "$rule"
    fi
  done
elif [[ "$GATE_ACTION" != status ]]; then
  die "Unsupported GATE_ACTION: $GATE_ACTION"
fi

rules="$(aws elbv2 describe-rules --listener-arn "$listener_arn")"
count="$(jq '[.Rules[] | select(.Priority=="1" or .Priority=="2")] | length' <<< "$rules")"
if [[ "$GATE_ACTION" == enable ]]; then
  [[ "$count" == 2 ]] || die "Write Gate enable verification failed: count=$count"
  for priority in 1 2; do
    rule="$(jq -r --arg p "$priority" '.Rules[] | select(.Priority==$p) | .RuleArn' <<< "$rules")"
    is_owned "$rule" || die "Write Gate priority $priority ownership verification failed"
    jq -e --arg p "$priority" '[.Rules[] | select(.Priority==$p and .Actions[0].Type=="fixed-response" and .Actions[0].FixedResponseConfig.StatusCode=="503" and .Actions[0].FixedResponseConfig.MessageBody=="{\"code\":\"MIGRATION_IN_PROGRESS\"}")] | length==1' <<< "$rules" >/dev/null \
      || die "Write Gate priority $priority response verification failed"
  done
  log 'Prod ALB Write Gate enabled'
elif [[ "$GATE_ACTION" == disable ]]; then
  [[ "$count" == 0 ]] || die "Write Gate disable verification failed: count=$count"
  log 'Prod ALB Write Gate disabled'
else
  log "Prod ALB Write Gate rule count=$count"
fi
