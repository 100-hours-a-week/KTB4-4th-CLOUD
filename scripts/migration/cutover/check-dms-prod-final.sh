#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/prod-common.sh"
: "${DMS_TASK_ARN:?Prod DMS task ARN required}"
: "${DMS_INSTANCE_ID:?Prod DMS replication instance identifier required}"
: "${EXPECTED_DMS_TABLES:?Comma-separated confirmed Prod table mapping required}"
[[ "$DMS_INSTANCE_ID" == *prod* ]] || die 'Refusing staging DMS instance'
[[ "$DMS_TASK_ARN" == arn:aws:dms:"$AWS_REGION":"$EXPECTED_ACCOUNT_ID":task:* ]] || die 'DMS task ARN account/region mismatch'
require_account
# Do not reuse staging's hardcoded seven-table validator.
task=$(aws dms describe-replication-tasks --filters "Name=replication-task-arn,Values=$DMS_TASK_ARN" --output json)
jq -e '.ReplicationTasks|length==1' <<< "$task" >/dev/null || die 'DMS task not unique'
jq -e '.ReplicationTasks[0].Status=="running" and .ReplicationTasks[0].MigrationType=="full-load-and-cdc" and .ReplicationTasks[0].ReplicationTaskStats.FullLoadProgressPercent==100' <<< "$task" >/dev/null || die 'DMS not ready'
stats=$(aws dms describe-table-statistics --replication-task-arn "$DMS_TASK_ARN" --output json)
IFS=, read -r -a tables <<< "$EXPECTED_DMS_TABLES"
for table in "${tables[@]}"; do
 jq -e --arg t "$table" '[.TableStatistics[]|select(.TableName==$t and (.ValidationFailedRecords//0)==0 and (.ValidationPendingRecords//0)==0 and (.ValidationSuspendedRecords//0)==0 and .ValidationState=="Validated")]|length==1' <<< "$stats" >/dev/null || die "DMS table not validated: $table"
done
# CloudWatch metrics must be recent; use GNU date on ubuntu runner.
for metric in CDCLatencySource CDCLatencyTarget; do
 start=$(date -u -d '10 minutes ago' +'%Y-%m-%dT%H:%M:%SZ'); end=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
 task_id=$(jq -r '.ReplicationTasks[0].ReplicationTaskIdentifier' <<< "$task")
 points=$(aws cloudwatch get-metric-statistics --namespace AWS/DMS --metric-name "$metric" --dimensions "Name=ReplicationInstanceIdentifier,Value=$DMS_INSTANCE_ID" "Name=ReplicationTaskIdentifier,Value=$task_id" --start-time "$start" --end-time "$end" --period 60 --statistics Maximum --output json)
 point=$(jq -c '[.Datapoints[]|select(.Maximum!=null)]|sort_by(.Timestamp)|last//empty' <<< "$points")
 [[ -n "$point" ]] || die "No $metric datapoint"
 age=$(( $(date -u +%s) - $(date -u -d "$(jq -r '.Timestamp' <<< "$point")" +%s) ))
 value=$(jq -r '.Maximum' <<< "$point")
 ((age>=0 && age<=180)) || die "Stale $metric"
 awk -v v="$value" 'BEGIN{exit !(v>=0 && v<=5)}' || die "Excessive $metric: $value"
 log "$metric=$value, age=${age}s"
done
log 'DMS CDC and validated table checks passed; independent final DB reconciliation is still mandatory.'
