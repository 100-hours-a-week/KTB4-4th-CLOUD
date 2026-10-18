#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "$0")/../common/common.sh"
check_url() { local name="$1" url="$2" allowed="$3" code; code="$(curl -sS --max-time 10 -o /dev/null -w '%{http_code}' "$url" || true)"; [[ ",$allowed," == *",$code,"* ]] && record_check "$name" PASS "HTTP $code" || record_check "$name" FAIL "expected [$allowed], actual HTTP ${code:-000}"; }
check_url "V1 frontend smoke" "$V1_SMOKE_URL" "200,307"
check_url "V2 frontend smoke" "$V2_SMOKE_URL" "200,307"
check_url "V1 backend reachability" "$V1_BACKEND_URL" "200,401,403"
check_url "V2 backend reachability" "$V2_BACKEND_URL" "200,401,403"
