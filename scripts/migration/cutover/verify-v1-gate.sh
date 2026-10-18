#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/prod-common.sh"
# This probe is not a substitute for verifying ALL write paths (incl. callback, batch, queues).
: "${GATE_PROBE_URL:?Set a safe, authorized non-mutating V1 gate verification URL}"
: "${GATE_EXPECTED_STATUS:=503}"
[[ "$GATE_PROBE_URL" == https://needu.gift/* ]] || die 'Gate probe must use live HTTPS host'
[[ "$GATE_EXPECTED_STATUS" == 503 ]] || die 'Only 503 accepted as write-gate signal'
# Probe URL MUST be an endpoint intentionally designed to return gate status without side effects.
status="$(curl -sS -o "$EVIDENCE_DIR/gate-response.txt" -w '%{http_code}' --max-time 10 --resolve "${LIVE_HOST}:443:${V1_EIP}" "$GATE_PROBE_URL")"
[[ "$status" == 503 ]] || die "V1 gate probe returned $status (expected 503)"
log 'V1 write gate probe returned 503; verify other write paths separately'
