#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "$0")/../common/common.sh"
task_json="$(aws dms describe-replication-tasks --filters "Name=replication-task-id,Values=$DMS_TASK_ID")"; task_arn="$(jq -r '.ReplicationTasks[0].ReplicationTaskArn // empty' <<<"$task_json")"
require_nonempty "DMS task" "$task_arn"; [[ -n "$task_arn" ]] || exit 0
require_equal "DMS task status" running "$(jq -r '.ReplicationTasks[0].Status' <<<"$task_json")"
require_equal "DMS migration type" full-load-and-cdc "$(jq -r '.ReplicationTasks[0].MigrationType' <<<"$task_json")"
require_equal "DMS full load progress" 100 "$(jq -r '.ReplicationTasks[0].ReplicationTaskStats.FullLoadProgressPercent' <<<"$task_json")"
stats="$(aws dms describe-table-statistics --replication-task-arn "$task_arn")"; expected='["ai_chat_rooms","auth_sessions","error_reports","friends","products","taste_analyses","users"]'
require_equal "DMS table set" "$expected" "$(jq -c '[.TableStatistics[].TableName] | sort' <<<"$stats")"
require_equal "DMS completed tables" 7 "$(jq '[.TableStatistics[] | select(.TableState == "Table completed")] | length' <<<"$stats")"
require_equal "DMS validated tables" 7 "$(jq '[.TableStatistics[] | select(.ValidationState == "Validated")] | length' <<<"$stats")"
require_equal "DMS validation failures" 0 "$(jq '[.TableStatistics[] | select((.ValidationFailedRecords // 0) != 0 or .ValidationState == "Validation failed")] | length' <<<"$stats")"
require_equal "DMS unapplied changes" 0 "$(jq '[.TableStatistics[] | (.Inserts // 0) + (.Updates // 0) + (.Deletes // 0) - (.AppliedInserts // 0) - (.AppliedUpdates // 0) - (.AppliedDeletes // 0)] | add // 0' <<<"$stats")"
require_equal "DMS load errors" 0 "$(jq '[.TableStatistics[].LoadErrorRows // 0] | add // 0' <<<"$stats")"
jq '{TableStatistics: [.TableStatistics[] | {TableName,TableState,ValidationState,FullLoadRows,Inserts,Updates,Deletes,AppliedInserts,AppliedUpdates,AppliedDeletes}]}' <<<"$stats" > "$PREFLIGHT_RESULT_DIR/dms.json"; printf '%s' "$task_arn" > "$PREFLIGHT_RESULT_DIR/dms-task-arn"
