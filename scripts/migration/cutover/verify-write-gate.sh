#!/usr/bin/env bash
set -euo pipefail

: "${STAGING_HOST:?STAGING_HOST is required}"

probe_url="https://${STAGING_HOST}/api/v1/__migration_write_gate_probe__"
response_file="$(mktemp)"
trap 'rm -f "$response_file"' EXIT

for attempt in {1..5}; do
  : > "$response_file"
  if status_code="$(curl \
    --silent \
    --show-error \
    --output "$response_file" \
    --write-out '%{http_code}' \
    --request POST \
    --header 'Content-Type: application/json' \
    --data '{}' \
    --connect-timeout 3 \
    --max-time 5 \
    "$probe_url")"; then
    if [[ "$status_code" == "503" ]] && \
      jq -e '.code == "MIGRATION_IN_PROGRESS"' "$response_file" >/dev/null 2>&1; then
      echo "[PASS] Write Gate probe attempt $attempt: POST $probe_url -> 503 MIGRATION_IN_PROGRESS"
      exit 0
    fi
  else
    status_code="curl-error"
  fi

  echo "Write Gate probe attempt $attempt/5 returned $status_code; waiting for ALB propagation."
  if (( attempt < 5 )); then
    sleep 2
  fi
done

echo "::error::Write Gate did not return 503 MIGRATION_IN_PROGRESS after 5 attempts (last status: $status_code)"
exit 1
