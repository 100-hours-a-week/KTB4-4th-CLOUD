#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_prod_common.sh"
for v in MYSQL_DB_IDENTIFIER POSTGRES_DB_IDENTIFIER; do need "$v" RDS; done
for item in "${MYSQL_DB_IDENTIFIER}:mysql" "${POSTGRES_DB_IDENTIFIER}:postgres"; do
  identifier="${item%%:*}"; engine="${item#*:}"
  json="$(aws rds describe-db-instances --db-instance-identifier "$identifier" --output json)" || fail RDS "$identifier not found"
  jq -e --arg id "$identifier" --arg engine "$engine" '.DBInstances[0] | .DBInstanceIdentifier==$id and .DBInstanceStatus=="available" and (.Engine|startswith($engine)) and (.Endpoint.Address|length>0)' <<< "$json" >/dev/null || fail RDS "$identifier unavailable or engine mismatch"
done
pass RDS 'MySQL and PostgreSQL RDS available (metadata only; no SQL reconciliation)'
