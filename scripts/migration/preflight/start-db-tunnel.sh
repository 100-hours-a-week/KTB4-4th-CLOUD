#!/usr/bin/env bash
set -euo pipefail
: "${SSM_BASTION_INSTANCE_ID:?}" "${MYSQL_HOST:?}" "${POSTGRES_HOST:?}" "${MYSQL_LOCAL_PORT:?}" "${POSTGRES_LOCAL_PORT:?}"

start_tunnel() {
  local host="$1" remote_port="$2" local_port="$3" log="$4"
  aws ssm start-session --target "$SSM_BASTION_INSTANCE_ID" --document-name AWS-StartPortForwardingSessionToRemoteHost \
    --parameters "{\"host\":[\"$host\"],\"portNumber\":[\"$remote_port\"],\"localPortNumber\":[\"$local_port\"]}" >"$log" 2>&1 &
  echo $!
}

mysql_pid="$(start_tunnel "$MYSQL_HOST" 3306 "$MYSQL_LOCAL_PORT" "$RUNNER_TEMP/mysql-tunnel.log")"
postgres_pid="$(start_tunnel "$POSTGRES_HOST" 5432 "$POSTGRES_LOCAL_PORT" "$RUNNER_TEMP/postgres-tunnel.log")"
echo "$mysql_pid $postgres_pid" > "$RUNNER_TEMP/preflight-tunnel-pids"

for port in "$MYSQL_LOCAL_PORT" "$POSTGRES_LOCAL_PORT"; do
  for _ in {1..30}; do nc -z 127.0.0.1 "$port" && break; sleep 1; done
  nc -z 127.0.0.1 "$port" || { echo "::error::Database tunnel on port $port did not open."; exit 1; }
done
