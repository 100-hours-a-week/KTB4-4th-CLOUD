#!/usr/bin/env bash
set -uo pipefail
: "${PREFLIGHT_RESULT_DIR:?Missing PREFLIGHT_RESULT_DIR}"
mkdir -p "$PREFLIGHT_RESULT_DIR"
record() {
  local name="$1" status="$2" detail="$3"
  detail="${detail//$'\t'/ }"
  detail="${detail//$'\n'/ }"
  printf '%s\t%s\t%s\n' "$name" "$status" "$detail" >> "$PREFLIGHT_RESULT_DIR/checks.tsv"
  if [[ "$status" == PASS ]]; then echo "[PASS] $name - $detail"; else echo "::error title=$name::$detail"; fi
}
pass() { record "$1" PASS "$2"; }
fail() { record "$1" FAIL "$2"; exit 1; }
need() { [[ -n "${!1:-}" ]] || fail "$2" "Required variable $1 missing"; }
