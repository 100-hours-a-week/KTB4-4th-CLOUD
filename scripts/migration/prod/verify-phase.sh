#!/usr/bin/env bash
set -euo pipefail
: "${PHASE:?missing PHASE}"
: "${AWS_REGION:?missing AWS_REGION}"
: "${AWS_ACCOUNT_ID:?missing AWS_ACCOUNT_ID}"
: "${ECS_CLUSTER:?missing ECS_CLUSTER}"
: "${PROD_ALB_NAME:?missing PROD_ALB_NAME}"

EVIDENCE_DIR="${RUNNER_TEMP:-/tmp}/prod-migration-evidence"
mkdir -p "$EVIDENCE_DIR"
LOG="$EVIDENCE_DIR/summary.md"
{
  echo "# Prod migration phase evidence"
  echo "- Phase: $PHASE"
  echo "- Verified at (UTC): $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  echo "- Verified at (KST): $(TZ=Asia/Seoul date +'%Y-%m-%d %H:%M:%S %Z')"
} > "$LOG"

actual_account="$(aws sts get-caller-identity --query Account --output text)"
[[ "$actual_account" == "$AWS_ACCOUNT_ID" ]] || { echo "Wrong account: $actual_account" >&2; exit 1; }

aws ecs describe-services --cluster "$ECS_CLUSTER" --services \
  needu-prod-frontend needu-prod-backend needu-prod-ai \
  --region "$AWS_REGION" \
  --query 'services[].{Name:serviceName,Desired:desiredCount,Running:runningCount,Pending:pendingCount,Status:status}' \
  --output json | tee "$EVIDENCE_DIR/ecs.json"

alb_arn="$(aws elbv2 describe-load-balancers --names "$PROD_ALB_NAME" --region "$AWS_REGION" --query 'LoadBalancers[0].LoadBalancerArn' --output text)"
listener="$(aws elbv2 describe-listeners --load-balancer-arn "$alb_arn" --region "$AWS_REGION" --query 'Listeners[?Port==`443`].ListenerArn | [0]' --output text)"
[[ -n "$listener" && "$listener" != None ]] || { echo 'HTTPS listener missing' >&2; exit 1; }
aws elbv2 describe-rules --listener-arn "$listener" --region "$AWS_REGION" > "$EVIDENCE_DIR/alb-rules.json"

jq -e '[.Rules[] | select(.Priority=="5" or .Priority=="20")] | length==2' "$EVIDENCE_DIR/alb-rules.json" >/dev/null

gate_count="$(jq '[.Rules[] | select(.Priority=="1" or .Priority=="2")] | length' "$EVIDENCE_DIR/alb-rules.json")"

case "$PHASE" in
  before|after-ecs|after-dns)
    [[ "$gate_count" == 0 ]] || { echo 'Gate should be OFF in this phase' >&2; exit 1; }
    ;;
  freeze|after-dms-stop|after-cutover)
    [[ "$gate_count" == 2 ]] || { echo 'Both ALB gate rules must exist' >&2; exit 1; }
    jq -e '[.Rules[] | select(.Priority=="1" or .Priority=="2") | select(.Actions[0].Type=="fixed-response" and .Actions[0].FixedResponseConfig.StatusCode=="503")] | length==2' "$EVIDENCE_DIR/alb-rules.json" >/dev/null
    ;;
  after-release)
    [[ "$gate_count" == 0 ]] || { echo 'Gate must be OFF after release' >&2; exit 1; }
    ;;
  *) echo "Unsupported phase: $PHASE" >&2; exit 1 ;;
esac

if [[ "$PHASE" != before ]]; then
  jq -e '[.[] | select(.Status=="ACTIVE" and .Desired>0 and .Running==.Desired and .Pending==0)] | length==3' "$EVIDENCE_DIR/ecs.json" >/dev/null || {
    echo 'V2 ECS services are not all fully running' >&2; exit 1;
  }
fi

if [[ -n "${PROD_DMS_TASK_ARN:-}" ]]; then
  aws dms describe-replication-tasks \
    --filters "Name=replication-task-arn,Values=$PROD_DMS_TASK_ARN" \
    --region "$AWS_REGION" \
    --query 'ReplicationTasks[].{Arn:ReplicationTaskArn,Status:Status,StopReason:StopReason}' \
    --output json > "$EVIDENCE_DIR/dms.json"

  jq -e 'length == 1' "$EVIDENCE_DIR/dms.json" >/dev/null || {
    echo 'ERROR: Expected exactly one DMS task' >&2
    exit 1
  }

  dms_status="$(jq -r '.[0].Status' "$EVIDENCE_DIR/dms.json")"
  echo "- DMS status: $dms_status" >> "$LOG"

  case "$PHASE" in
    after-ecs|after-dns|freeze)
      [[ "$dms_status" == running ]] || {
        echo "ERROR: DMS must be running during CDC phase, actual=$dms_status" >&2
        exit 1
      }
      ;;
    after-dms-stop|after-cutover|after-release)
      [[ "$dms_status" == stopped ]] || {
        echo "ERROR: DMS must be stopped, actual=$dms_status" >&2
        exit 1
      }
      ;;
  esac
else
  case "$PHASE" in
    after-dms-stop|after-cutover|after-release)
      echo 'ERROR: PROD_DMS_TASK_ARN is required in this phase' >&2
      exit 1
      ;;
    *)
      echo '- DMS: not checked (PROD_DMS_TASK_ARN not configured)' >> "$LOG"
      ;;
  esac
fi

echo "- ALB gate rules: $gate_count" >> "$LOG"
echo '- IMPORTANT: No DB reconciliation, HTTP smoke, V1 nginx gate, DNS, or V2 write detection was performed.' >> "$LOG"
echo '- This is phase evidence only, NOT authorization for cutover or rollback.' >> "$LOG"
cat "$LOG"

# Prod Target Group ARNs
V1_BE_TG_ARN="arn:aws:elasticloadbalancing:ap-northeast-2:919551759796:targetgroup/needu-prod-v1/377114499401e8f8"
V1_FE_TG_ARN="$V1_BE_TG_ARN"
V2_BE_TG_ARN="arn:aws:elasticloadbalancing:ap-northeast-2:919551759796:targetgroup/needu-prod-be/9d2e56edf203f40f"
V2_FE_TG_ARN="arn:aws:elasticloadbalancing:ap-northeast-2:919551759796:targetgroup/needu-prod-fe/ff2eddc5fe62b4de"

ALB_ARN="$(aws elbv2 describe-load-balancers   --names needu-prod-alb   --region ap-northeast-2   --query 'LoadBalancers[0].LoadBalancerArn'   --output text)"

# Verify ALB routing weights by target group identity.
verify_routing_weights() {
  local expected_v1="$1"
  local expected_v2="$2"
  local listener_arn rules_json

  listener_arn="$(aws elbv2 describe-listeners \
    --load-balancer-arn "$ALB_ARN" \
    --query 'Listeners[?Port==`443`].ListenerArn | [0]' \
    --output text)"

  [[ -n "$listener_arn" && "$listener_arn" != "None" ]] || {
    echo "ERROR: HTTPS listener not found"
    return 1
  }

  rules_json="$(aws elbv2 describe-rules \
    --listener-arn "$listener_arn" --output json)"

  for priority in 5 20; do
    local expected_v1_arn expected_v2_arn

    case "$priority" in
      5)
        expected_v1_arn="$V1_BE_TG_ARN"
        expected_v2_arn="$V2_BE_TG_ARN"
        ;;
      20)
        expected_v1_arn="$V1_FE_TG_ARN"
        expected_v2_arn="$V2_FE_TG_ARN"
        ;;
    esac

    jq -e \
      --arg priority "$priority" \
      --arg v1 "$expected_v1_arn" \
      --arg v2 "$expected_v2_arn" \
      --argjson w1 "$expected_v1" \
      --argjson w2 "$expected_v2" '
        [.Rules[] | select(.Priority == $priority)] | length == 1
      ' <<< "$rules_json" >/dev/null || return 1

    jq -e \
      --arg priority "$priority" \
      --arg v1 "$expected_v1_arn" \
      --arg v2 "$expected_v2_arn" \
      --argjson w1 "$expected_v1" \
      --argjson w2 "$expected_v2" '
        [.Rules[] | select(.Priority == $priority)] | .[0].Actions
        | map(select(.Type == "forward"))
        | length == 1
      ' <<< "$rules_json" >/dev/null || return 1

    jq -e \
      --arg priority "$priority" \
      --arg v1 "$expected_v1_arn" \
      --arg v2 "$expected_v2_arn" \
      --argjson w1 "$expected_v1" \
      --argjson w2 "$expected_v2" '
        [.Rules[] | select(.Priority == $priority)][0]
        | [.Actions[] | select(.Type == "forward")][0]
        | .ForwardConfig.TargetGroups
        | (length == 2)
          and (any(.[]; .TargetGroupArn == $v1 and .Weight == $w1))
          and (any(.[]; .TargetGroupArn == $v2 and .Weight == $w2))
      ' <<< "$rules_json" >/dev/null || {
        echo "ERROR: priority=$priority routing weights mismatch"
        return 1
      }

    echo "PASS: priority=$priority V1=$expected_v1 V2=$expected_v2"
  done
}

case "${PHASE:-}" in
  before|after-ecs|after-dns|freeze|after-dms-stop)
    verify_routing_weights 100 0
    ;;
  after-cutover|after-release)
    verify_routing_weights 0 100
    ;;
esac

# Verify Route53 authoritative record for each migration phase.
verify_dns_phase() {
  local record_json
  record_json="$(aws route53 list-resource-record-sets \
    --hosted-zone-id Z10258582M6TRCEOCUBUW \
    --query "ResourceRecordSets[?Name=='needu.gift.' && Type=='A']" \
    --output json)"

  case "$PHASE" in
    before|after-ecs)
      jq -e '
        length == 1
        and .[0].ResourceRecords == [{"Value":"13.124.155.10"}]
      ' <<< "$record_json" >/dev/null || {
        echo "ERROR: needu.gift must point to V1 EIP"
        return 1
      }
      ;;
    after-dns|freeze|after-dms-stop|after-cutover|after-release)
      jq -e '
        length == 1
        and .[0].AliasTarget.DNSName != null
        and (.[0].AliasTarget.DNSName
          | rtrimstr(".")
          | ascii_downcase) ==
          "needu-prod-alb-314721872.ap-northeast-2.elb.amazonaws.com"
      ' <<< "$record_json" >/dev/null || {
        echo "ERROR: needu.gift must point to Prod ALB"
        return 1
      }
      ;;
  esac

  echo "PASS: Route53 DNS matches phase=$PHASE"
}

verify_dns_phase

# Verify Route53 authoritative record for each migration phase.
verify_dns_phase() {
  local record_json
  record_json="$(aws route53 list-resource-record-sets \
    --hosted-zone-id Z10258582M6TRCEOCUBUW \
    --query "ResourceRecordSets[?Name=='needu.gift.' && Type=='A']" \
    --output json)"

  case "$PHASE" in
    before|after-ecs)
      jq -e '
        length == 1
        and .[0].ResourceRecords == [{"Value":"13.124.155.10"}]
      ' <<< "$record_json" >/dev/null || {
        echo "ERROR: needu.gift must point to V1 EIP"
        return 1
      }
      ;;
    after-dns|freeze|after-dms-stop|after-cutover|after-release)
      jq -e '
        length == 1
        and .[0].AliasTarget.DNSName != null
        and (.[0].AliasTarget.DNSName
          | rtrimstr(".")
          | ascii_downcase) ==
          "needu-prod-alb-314721872.ap-northeast-2.elb.amazonaws.com"
      ' <<< "$record_json" >/dev/null || {
        echo "ERROR: needu.gift must point to Prod ALB"
        return 1
      }
      ;;
  esac

  echo "PASS: Route53 DNS matches phase=$PHASE"
}

verify_dns_phase
