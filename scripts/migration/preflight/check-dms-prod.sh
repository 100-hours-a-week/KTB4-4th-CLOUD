#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_prod_common.sh"
need DMS_TASK_ID DMS
[[ "$DMS_TASK_ID" == *prod* ]] || fail DMS 'DMS_TASK_ID must explicitly identify Prod task'
json="$(aws dms describe-replication-tasks --filters "Name=replication-task-id,Values=$DMS_TASK_ID" --output json)" || fail DMS 'DMS lookup failed'
count="$(jq '.ReplicationTasks | length' <<< "$json")"
[[ "$count" == 1 ]] || fail DMS "Expected exactly one Prod DMS task, found $count"
arn="$(jq -r '.ReplicationTasks[0].ReplicationTaskArn' <<< "$json")"
status="$(jq -r '.ReplicationTasks[0].Status' <<< "$json")"
[[ "$status" == running ]] || fail DMS "Prod DMS task not running: $status"
# Require ongoing replication and initial full load completion.
jq -e '.ReplicationTasks[0].MigrationType=="full-load-and-cdc" and .ReplicationTasks[0].ReplicationTaskStats.FullLoadProgressPercent==100' <<< "$json" >/dev/null || fail DMS 'Full-load + CDC task not fully loaded'
stats="$(aws dms describe-table-statistics --replication-task-arn "$arn" --output json)" || fail DMS 'Table statistics lookup failed'
jq -e '(.TableStatistics|length)>0 and ([.TableStatistics[] | select((.ValidationFailedRecords // 0)>0 or (.ValidationPendingRecords // 0)>0 or (.ValidationSuspendedRecords // 0)>0 or (.TableState != "Table completed" and .TableState != "Table is being replicated"))] | length)==0' <<< "$stats" >/dev/null || fail DMS 'DMS validation errors/pending or tables not ready'
# ValidationEnabled and CDC latency checks must be reviewed for the actual task before cutover.
printf '%s' "$arn" > "$PREFLIGHT_RESULT_DIR/dms-task-arn.txt"
pass DMS "Prod DMS running; full-load 100%; table stats no pending/failed validation (CDC lag still requires review)"
