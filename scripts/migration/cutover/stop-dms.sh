#!/usr/bin/env bash
set -euo pipefail
: "${DMS_TASK_ARN:?required}"
AWS_REGION="${AWS_REGION:-ap-northeast-2}"
DMS_STOP_TIMEOUT_SECONDS="${DMS_STOP_TIMEOUT_SECONDS:-180}"
fail() { echo "::error::$*" >&2; exit 1; }
status() {
  aws dms describe-replication-tasks --region "$AWS_REGION" \
    --filters "Name=replication-task-arn,Values=$DMS_TASK_ARN" \
    --query 'ReplicationTasks[0].Status' --output text
}
initial=$(status)
echo "Initial DMS status: $initial"
[[ "$initial" == running ]] || fail "Refusing to stop DMS from status: $initial"
aws dms stop-replication-task --region "$AWS_REGION" --replication-task-arn "$DMS_TASK_ARN" >/dev/null
deadline=$((SECONDS + DMS_STOP_TIMEOUT_SECONDS))
while (( SECONDS < deadline )); do
  current=$(status)
  echo "DMS status: $current"
  if [[ "$current" == stopped ]]; then
    echo "DMS_STOPPED_AT=$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
    exit 0
  fi
  [[ "$current" == stopping || "$current" == running ]] || fail "Unexpected DMS state: $current"
  sleep 5
done
fail 'DMS stop timeout; manual inspection required'
