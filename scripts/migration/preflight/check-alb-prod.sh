#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/_prod_common.sh"

CHECK="ALB"

for v in \
  ALB_NAME \
  FRONTEND_TARGET_GROUP \
  BACKEND_TARGET_GROUP \
  PROD_HOST \
  LIVE_HOST \
  PREFLIGHT_RESULT_DIR
do
  need "$v" "$CHECK"
done

# 1. ALB 및 HTTPS Listener 조회
alb_arn="$(aws elbv2 describe-load-balancers \
  --names "$ALB_NAME" \
  --query 'LoadBalancers[0].LoadBalancerArn' \
  --output text)" || fail "$CHECK" 'ALB not found'

listener_arn="$(aws elbv2 describe-listeners \
  --load-balancer-arn "$alb_arn" \
  --query 'Listeners[?Port==`443`].ListenerArn | [0]' \
  --output text)" || fail "$CHECK" 'HTTPS listener lookup failed'

[[ -n "$listener_arn" && "$listener_arn" != "None" ]] \
  || fail "$CHECK" 'HTTPS 443 listener missing'

rules="$(aws elbv2 describe-rules \
  --listener-arn "$listener_arn" \
  --output json)" || fail "$CHECK" 'Listener rules lookup failed'

# 2. Target Group ARN 조회
v1_arn="$(aws elbv2 describe-target-groups \
  --names needu-prod-v1 \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text)" || fail "$CHECK" 'V1 Target Group missing'

fe_arn="$(aws elbv2 describe-target-groups \
  --names "$FRONTEND_TARGET_GROUP" \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text)" || fail "$CHECK" 'Frontend Target Group missing'

be_arn="$(aws elbv2 describe-target-groups \
  --names "$BACKEND_TARGET_GROUP" \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text)" || fail "$CHECK" 'Backend Target Group missing'

# 3. Priority별 ALB 라우팅 검증
check_routing() {
  local priority="$1"
  local path="$2"
  local v2_arn="$3"

  local matched

  matched="$(jq -r \
    --arg priority "$priority" \
    --arg path "$path" \
    --arg live "$LIVE_HOST" \
    --arg prod "$PROD_HOST" \
    --arg v1 "$v1_arn" \
    --arg v2 "$v2_arn" '
    [
      .Rules[]
      | select(.Priority == $priority)

      | select(
          (
            [.Conditions[]
             | select(.Field == "host-header")
             | .Values[]]
          ) as $hosts
          | ($hosts | index($live)) != null
            and ($hosts | index($prod)) != null
        )

      | select(
          (
            [.Conditions[]
             | select(.Field == "path-pattern")
             | .Values[]]
          ) as $paths
          | ($paths | index($path)) != null
        )

      | .Actions[]
      | select(.Type == "forward")
      | .ForwardConfig.TargetGroups

      | select(length == 2)

      | select(
          any(.[];
            .TargetGroupArn == $v1
            and .Weight == 100
          )
        )

      | select(
          any(.[];
            .TargetGroupArn == $v2
            and .Weight == 0
          )
        )
    ]
    | length
  ' <<< "$rules")" || fail "$CHECK" "Priority $priority jq evaluation failed"

  [[ "$matched" == "1" ]] \
    || fail "$CHECK" "Priority $priority routing mismatch (matched=$matched)"

  echo "[PASS] Priority $priority: V1=100, V2=0, path=$path"
}

# API: V1 100%, V2 Backend 0%
check_routing "5" "/api/v1/*" "$be_arn"

# Frontend: V1 100%, V2 Frontend 0%
check_routing "20" "/*" "$fe_arn"

# 4. V1 Target Health 확인
health="$(aws elbv2 describe-target-health \
  --target-group-arn "$v1_arn" \
  --output json)" || fail "$CHECK" 'V1 Target Health lookup failed'

healthy_count="$(jq -r '
  [
    .TargetHealthDescriptions[]
    | select(.TargetHealth.State == "healthy")
  ]
  | length
' <<< "$health")"

[[ "$healthy_count" =~ ^[0-9]+$ ]] \
  || fail "$CHECK" 'Invalid Target Health response'

(( healthy_count >= 1 )) \
  || fail "$CHECK" 'V1 Target Group has no healthy targets'

echo "[PASS] V1 Target Group: healthy=$healthy_count"

# 5. Write Gate 비활성화 확인
gate_count="$(jq -r '
  [
    .Rules[]
    | select(.Priority == "1" or .Priority == "2")
  ]
  | length
' <<< "$rules")"

[[ "$gate_count" == "0" ]] \
  || fail "$CHECK" "Write Gate rules present: $gate_count"

echo "[PASS] ALB Write Gate: disabled"

# 6. 검증 증적 저장
mkdir -p "$PREFLIGHT_RESULT_DIR"

printf '%s\n' "$rules" \
  > "$PREFLIGHT_RESULT_DIR/alb-rules.json"

printf '%s\n' "$health" \
  > "$PREFLIGHT_RESULT_DIR/v1-target-health.json"

# 7. 최종 PASS
pass "$CHECK" \
  'Priority 5/20 V1=100 V2=0; V1 healthy; Write Gate disabled'
