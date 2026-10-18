#!/usr/bin/env bash
set -uo pipefail
: "${PREFLIGHT_RESULT_DIR:?PREFLIGHT_RESULT_DIR is required}"
mkdir -p "$PREFLIGHT_RESULT_DIR"
CHECKS_TSV="$PREFLIGHT_RESULT_DIR/checks.tsv"
touch "$CHECKS_TSV"
record_check() { local name="$1" status="$2" detail="$3"; printf '%s\t%s\t%s\n' "$name" "$status" "${detail//$'\t'/ }" >> "$CHECKS_TSV"; [[ "$status" == PASS ]] && echo "[PASS] $name - $detail" || echo "::error title=$name::$detail"; }
require_equal() { local name="$1" expected="$2" actual="$3"; [[ "$actual" == "$expected" ]] && record_check "$name" PASS "$actual" || record_check "$name" FAIL "expected=$expected, actual=${actual:-missing}"; }
require_nonempty() { local name="$1" actual="$2"; [[ -n "$actual" && "$actual" != None && "$actual" != null ]] && record_check "$name" PASS "$actual" || record_check "$name" FAIL "value is missing"; }
