#!/usr/bin/env bash
set -euo pipefail
: "${DMS_TASK_ARN:?required}"
AWS_REGION="${AWS_REGION:-ap-northeast-2}"
DMS_INSTANCE_ID="${DMS_INSTANCE_ID:-needu-staging-dms}"
DMS_TASK_ID="${DMS_TASK_ARN##*:}"
MAX_CDC_LATENCY_SECONDS="${MAX_CDC_LATENCY_SECONDS:-5}"
MAX_METRIC_AGE_SECONDS="${MAX_METRIC_AGE_SECONDS:-180}"
EXPECTED=(users friends products taste_analyses auth_sessions ai_chat_rooms error_reports)
fail() { echo "::error::$*" >&2; exit 1; }
command -v jq >/dev/null || fail 'jq required'
command -v aws >/dev/null || fail 'aws CLI required'
[[ "$MAX_CDC_LATENCY_SECONDS" =~ ^[0-9]+([.][0-9]+)?$ ]] || fail 'invalid latency threshold'
[[ "$MAX_METRIC_AGE_SECONDS" =~ ^[0-9]+$ ]] || fail 'invalid metric age threshold'
task=$(aws dms describe-replication-tasks --region "$AWS_REGION" --filters "Name=replication-task-arn,Values=$DMS_TASK_ARN" --output json)
[[ "$(jq '.ReplicationTasks | length' <<<"$task")" == 1 ]] || fail 'DMS task not found or ambiguous'
[[ "$(jq -r '.ReplicationTasks[0].Status' <<<"$task")" == running ]] || fail 'DMS task must be running'
[[ "$(jq -r '.ReplicationTasks[0].ReplicationTaskStats.TablesErrored // 0' <<<"$task")" == 0 ]] || fail 'DMS task has errored tables'
stats=$(aws dms describe-table-statistics --region "$AWS_REGION" --replication-task-arn "$DMS_TASK_ARN" --output json)
[[ "$(jq '.TableStatistics | length' <<<"$stats")" == 7 ]] || fail 'Expected exactly 7 replicated tables'
for table in "${EXPECTED[@]}"; do
  jq -e --arg name "$table" '
    [.TableStatistics[] | select(.TableName == $name)] as $rows |
    ($rows | length) == 1 and
    $rows[0].TableState == "Table completed" and
    $rows[0].ValidationState == "Validated" and
    $rows[0].ValidationFailedRecords == 0
  ' <<<"$stats" >/dev/null || fail "Table verification failed: $table"
  echo "TABLE PASS: $table"
done
metric_check() {
  local name="$1" start end json point value stamp now epoch age
  start=$(date -u -d '10 minutes ago' +'%Y-%m-%dT%H:%M:%SZ')
  end=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
  json=$(aws cloudwatch get-metric-statistics --region "$AWS_REGION" \
    --namespace AWS/DMS --metric-name "$name" \
    --dimensions "Name=ReplicationInstanceIdentifier,Value=$DMS_INSTANCE_ID" \
                 "Name=ReplicationTaskIdentifier,Value=$DMS_TASK_ID" \
    --start-time "$start" --end-time "$end" --period 60 --statistics Maximum --output json)
  point=$(jq -c '[.Datapoints[] | select(.Maximum != null)] | sort_by(.Timestamp) | last // empty' <<<"$json")
  [[ -n "$point" ]] || fail "No CloudWatch datapoint: $name"
  value=$(jq -r '.Maximum' <<<"$point")
  stamp=$(jq -r '.Timestamp' <<<"$point")
  now=$(date -u +%s)
  epoch=$(date -u -d "$stamp" +%s)
  age=$((now - epoch))
  echo "$name=$value seconds; metric_age=$age seconds"
  (( age >= 0 && age <= MAX_METRIC_AGE_SECONDS )) || fail "Stale/future metric: $name"
  awk -v v="$value" -v max="$MAX_CDC_LATENCY_SECONDS" 'BEGIN {exit !(v >= 0 && v <= max)}' || fail "Latency too high: $name=$value"
}
metric_check CDCLatencySource
metric_check CDCLatencyTarget
echo 'DMS_CDC_CHECK=PASS'
