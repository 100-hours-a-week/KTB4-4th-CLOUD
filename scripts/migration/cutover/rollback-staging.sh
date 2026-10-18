#!/usr/bin/env bash
set -euo pipefail

: "${LISTENER:?LISTENER is required}"
: "${V1_TG:?V1_TG is required}"
: "${FE_TG:?FE_TG is required}"
: "${BE_TG:?BE_TG is required}"

GATE_TAG_VALUE="${GATE_TAG_VALUE:-StagingMigrationWriteGate}"
API_RULE_PRIORITY="${API_RULE_PRIORITY:-5}"
FRONTEND_RULE_PRIORITY="${FRONTEND_RULE_PRIORITY:-20}"

healthy_count="$(aws elbv2 describe-target-health \
  --target-group-arn "$V1_TG" \
  --query "length(TargetHealthDescriptions[?TargetHealth.State=='healthy'])" \
  --output text)"

if [[ "$healthy_count" -lt 1 ]]; then
  echo '::error::Automatic recovery stopped because V1 has no healthy targets'
  exit 1
fi

rules_json="$(aws elbv2 describe-rules --listener-arn "$LISTENER")"
api_rule_arn="$(jq -er --arg priority "$API_RULE_PRIORITY" \
  '.Rules[] | select(.Priority == $priority) | .RuleArn' <<< "$rules_json")"
frontend_rule_arn="$(jq -er --arg priority "$FRONTEND_RULE_PRIORITY" \
  '.Rules[] | select(.Priority == $priority) | .RuleArn' <<< "$rules_json")"

v1_action() {
  local v2_target_group="$1"
  jq -cn \
    --arg v1 "$V1_TG" \
    --arg v2 "$v2_target_group" \
    '{
      Type:"forward",
      ForwardConfig:{
        TargetGroups:[
          {TargetGroupArn:$v1,Weight:100},
          {TargetGroupArn:$v2,Weight:0}
        ]
      }
    }'
}

# Keep the Write Gate enabled until both routing rules are confirmed on V1.
aws elbv2 modify-rule \
  --rule-arn "$api_rule_arn" \
  --actions "$(v1_action "$BE_TG")" >/dev/null
aws elbv2 modify-rule \
  --rule-arn "$frontend_rule_arn" \
  --actions "$(v1_action "$FE_TG")" >/dev/null

verify_v1_weights() {
  local rule_arn="$1"
  local v2_target_group="$2"
  local rule_json

  rule_json="$(aws elbv2 describe-rules --rule-arns "$rule_arn")"
  jq -e \
    --arg v1 "$V1_TG" \
    --arg v2 "$v2_target_group" '
      .Rules[0].Actions[]
      | select(.Type == "forward")
      | .ForwardConfig.TargetGroups as $groups
      | ([$groups[] | select(.TargetGroupArn == $v1 and .Weight == 100)] | length) == 1
        and ([$groups[] | select(.TargetGroupArn == $v2 and .Weight == 0)] | length) == 1
    ' <<< "$rule_json" >/dev/null
}

verify_v1_weights "$api_rule_arn" "$BE_TG"
verify_v1_weights "$frontend_rule_arn" "$FE_TG"
echo '[PASS] API and frontend traffic restored to V1 100%'

rules_json="$(aws elbv2 describe-rules --listener-arn "$LISTENER")"
for priority in 1 2; do
  gate_rule_arn="$(jq -r --arg priority "$priority" \
    '.Rules[] | select(.Priority == $priority) | .RuleArn' <<< "$rules_json")"

  if [[ -z "$gate_rule_arn" ]]; then
    continue
  fi

  purpose="$(aws elbv2 describe-tags \
    --resource-arns "$gate_rule_arn" \
    --query "TagDescriptions[0].Tags[?Key=='Purpose'].Value | [0]" \
    --output text)"

  if [[ "$purpose" != "$GATE_TAG_VALUE" ]]; then
    echo "::error::Refusing to delete unowned rule at priority $priority"
    exit 1
  fi

  aws elbv2 delete-rule --rule-arn "$gate_rule_arn"
done

rules_json="$(aws elbv2 describe-rules --listener-arn "$LISTENER")"
jq -e '[.Rules[] | select(.Priority == "1" or .Priority == "2")] | length == 0' \
  <<< "$rules_json" >/dev/null

healthy_count="$(aws elbv2 describe-target-health \
  --target-group-arn "$V1_TG" \
  --query "length(TargetHealthDescriptions[?TargetHealth.State=='healthy'])" \
  --output text)"
test "$healthy_count" -ge 1

echo '[PASS] V1 target health confirmed and Write Gate disabled'
echo '[INFO] DMS task was not restarted automatically'
