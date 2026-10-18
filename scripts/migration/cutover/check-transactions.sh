#!/usr/bin/env bash
set -euo pipefail
: "${V1_INSTANCE_ID:?required}"
AWS_REGION="${AWS_REGION:-ap-northeast-2}"
SSM_TIMEOUT_SECONDS="${SSM_TIMEOUT_SECONDS:-90}"
POLL_INTERVAL_SECONDS=3
REMOTE_SCRIPT=$(cat <<'REMOTE'
#!/usr/bin/env bash
set -euo pipefail
mysql_count=$(sudo mysql --batch --skip-column-names -e 'SELECT COUNT(*) FROM information_schema.innodb_trx;' | tr -d '[:space:]')
postgres_count=$(sudo -n -u postgres psql -X -d needu_vector -Atqc "SELECT COUNT(*) FROM pg_stat_activity WHERE datname = 'needu_vector' AND pid <> pg_backend_pid() AND xact_start IS NOT NULL;" | tr -d '[:space:]')
[[ "$mysql_count" =~ ^[0-9]+$ ]] || exit 1
[[ "$postgres_count" =~ ^[0-9]+$ ]] || exit 1
printf 'MYSQL_TRANSACTIONS=%s\nPOSTGRES_TRANSACTIONS=%s\n' "$mysql_count" "$postgres_count"
[[ "$mysql_count" == 0 && "$postgres_count" == 0 ]] || exit 1
echo 'TRANSACTION_CHECK=PASS'
REMOTE
)
fail() { echo "::error::$*" >&2; exit 1; }
check_once() {
  local attempt="$1" id status output err deadline
  echo "Transaction check $attempt/2"
  encoded=$(printf %s "$REMOTE_SCRIPT" | base64 | tr -d "\n")
  id=$(aws ssm send-command --region "$AWS_REGION" --instance-ids "$V1_INSTANCE_ID" \
    --document-name AWS-RunShellScript \
    --parameters "$(jq -cn --arg cmd "printf %s $encoded | base64 -d | bash" '{commands:[$cmd]}')" \
    --query Command.CommandId --output text)
  deadline=$((SECONDS + SSM_TIMEOUT_SECONDS))
  while (( SECONDS < deadline )); do
    if status=$(aws ssm get-command-invocation --region "$AWS_REGION" --command-id "$id" \
      --instance-id "$V1_INSTANCE_ID" --query Status --output text 2>/dev/null); then
      case "$status" in
        Success) break ;;
        Failed|Cancelled|TimedOut|Cancelling) fail "SSM invocation failed: $status" ;;
        Pending|InProgress|Delayed) ;;
        *) fail "Unexpected SSM status: $status" ;;
      esac
    fi
    sleep "$POLL_INTERVAL_SECONDS"
  done
  [[ "${status:-}" == Success ]] || fail 'SSM timed out'
  output=$(aws ssm get-command-invocation --region "$AWS_REGION" --command-id "$id" \
    --instance-id "$V1_INSTANCE_ID" --query StandardOutputContent --output text)
  echo "$output"
  grep -qx 'MYSQL_TRANSACTIONS=0' <<<"$output" || fail 'MySQL open transactions not zero'
  grep -qx 'POSTGRES_TRANSACTIONS=0' <<<"$output" || fail 'Postgres open transactions not zero'
  grep -qx 'TRANSACTION_CHECK=PASS' <<<"$output" || fail 'Remote check did not pass'
}
check_once 1
sleep 5
check_once 2
echo 'TRANSACTIONS_CHECK=PASS'
