#!/usr/bin/env bash
set -euo pipefail

: "${LIVE_HOST:=needu.gift}"

body="$(mktemp)"
trap 'rm -f "$body"' EXIT
status="$(curl --silent --show-error --output "$body" --write-out '%{http_code}' \
  --request POST --header 'Content-Type: application/json' --data '{}' \
  --connect-timeout 3 --max-time 5 \
  "https://${LIVE_HOST}/api/v1/__migration_write_gate_probe__")"

[[ "$status" == 503 ]] || { echo "::error::Prod Write Gate returned HTTP $status"; exit 1; }
jq -e '.code=="MIGRATION_IN_PROGRESS"' "$body" >/dev/null || {
  echo '::error::Prod Write Gate body mismatch'
  exit 1
}
echo "[PASS] Prod Write Gate HTTP probe -> 503 MIGRATION_IN_PROGRESS"
