#!/usr/bin/env bash
set -euo pipefail

: "${LIVE_HOST:=needu.gift}"

body="$(mktemp)"
trap 'rm -f "$body"' EXIT
probe_url="https://${LIVE_HOST}/api/v1/__migration_write_gate_probe__"

for attempt in {1..5}; do
  : > "$body"
  if status="$(curl --silent --show-error --output "$body" --write-out '%{http_code}' \
    --request POST --header 'Content-Type: application/json' --data '{}' \
    --connect-timeout 3 --max-time 5 \
    "$probe_url")"; then
    if [[ "$status" == 503 ]] && \
      jq -e '.code=="MIGRATION_IN_PROGRESS"' "$body" >/dev/null 2>&1; then
      echo "[PASS] Prod Write Gate probe attempt $attempt: POST $probe_url -> 503 MIGRATION_IN_PROGRESS"
      exit 0
    fi
  else
    status="curl-error"
  fi

  echo "Prod Write Gate probe attempt $attempt/5 returned $status; waiting for ALB propagation."
  if (( attempt < 5 )); then
    sleep 2
  fi
done

echo "::error::Prod Write Gate did not return 503 MIGRATION_IN_PROGRESS after 5 attempts (last status: $status)"
exit 1
