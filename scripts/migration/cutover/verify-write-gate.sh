#!/usr/bin/env bash
set -euo pipefail

: "${STAGING_HOST:?STAGING_HOST is required}"

probe_url="https://${STAGING_HOST}/api/v1/__migration_write_gate_probe__"
response_file="$(mktemp)"
trap 'rm -f "$response_file"' EXIT

status_code="$(curl \
  --silent \
  --show-error \
  --output "$response_file" \
  --write-out '%{http_code}' \
  --request POST \
  --header 'Content-Type: application/json' \
  --data '{}' \
  --connect-timeout 10 \
  --max-time 20 \
  "$probe_url")"

if [[ "$status_code" != "503" ]]; then
  echo "::error::Write Gate probe returned HTTP $status_code instead of 503"
  exit 1
fi

if ! jq -e '.code == "MIGRATION_IN_PROGRESS"' "$response_file" >/dev/null; then
  echo '::error::Write Gate probe response does not contain MIGRATION_IN_PROGRESS'
  exit 1
fi

echo "[PASS] Write Gate probe: POST $probe_url -> 503 MIGRATION_IN_PROGRESS"
