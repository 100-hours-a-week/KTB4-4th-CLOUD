#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

for cmd in k6 python3 jq tee; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "ERROR: Required command not found: $cmd" >&2
    exit 1
  }
done

# 명시적 URL 지정 필수: 잘못된 환경에 부하를 보내지 않는다.
: "${BASE_URL:?Set BASE_URL explicitly, e.g. https://staging.needu.gift}"

BASE_URL="${BASE_URL%/}"
case "$BASE_URL" in
  https://staging.needu.gift) ;;
  *)
    echo "ERROR: This rehearsal script only permits https://staging.needu.gift" >&2
    echo "Received BASE_URL: $BASE_URL" >&2
    exit 1
    ;;
esac

export BASE_URL
export RATE="${RATE:-1}"
export DURATION="${DURATION:-30s}"
export VUS="${VUS:-5}"
export MAX_VUS="${MAX_VUS:-10}"
export TIMEOUT="${TIMEOUT:-10s}"
export K6_PROMETHEUS_RW_SERVER_URL="${K6_PROMETHEUS_RW_SERVER_URL:-http://localhost:9090/api/v1/write}"
export K6_PROMETHEUS_RW_TREND_STATS="${K6_PROMETHEUS_RW_TREND_STATS:-p(95)}"

[[ -f data/users.json ]] || {
  echo "ERROR: data/users.json not found" >&2
  exit 1
}

python3 - <<'PY'
import json
from pathlib import Path

users = json.loads(Path("data/users.json").read_text(encoding="utf-8"))

if not isinstance(users, list) or len(users) != 20:
    raise SystemExit("ERROR: data/users.json must contain exactly 20 accounts")

tokens = set()

for i, user in enumerate(users, 1):
    if not isinstance(user, dict):
        raise SystemExit(f"ERROR: User {i} is invalid")

    for field in ("token", "friendUserId", "giftUserId"):
        value = user.get(field)
        if value is None or not str(value).strip():
            raise SystemExit(f"ERROR: User {i} missing {field}")

    token = user["token"]
    if not isinstance(token, str) or token.startswith("REPLACE_WITH_"):
        raise SystemExit(f"ERROR: Invalid JWT for user {i}")

    if token in tokens:
        raise SystemExit("ERROR: Duplicate JWT detected")

    tokens.add(token)

print(f"Validated test accounts: {len(users)}")
PY

mkdir -p results

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
RUN_DIR="$ROOT/results/$STAMP"
mkdir -p "$RUN_DIR/results"

LOG="$RUN_DIR/console.log"

{
  echo "========================================"
  echo "NeedU Staging Migration k6 Test"
  echo "Started UTC: $STAMP"
  echo "Started KST: $(TZ=Asia/Seoul date '+%Y-%m-%d %H:%M:%S %Z')"
  echo "Base URL: $BASE_URL"
  echo "Rate: $RATE iterations/s"
  echo "Duration: $DURATION"
  echo "VUs: $VUS"
  echo "Max VUs: $MAX_VUS"
  echo "Prometheus URL: $K6_PROMETHEUS_RW_SERVER_URL"
  echo "Results: $RUN_DIR"
  echo "========================================"
} | tee "$LOG"

cd "$RUN_DIR"

# 파이프라인에서 tee의 종료 코드가 아닌 k6의 종료 코드를 보존한다.
set +e
k6 run \
  --out "json=$RUN_DIR/metrics.jsonl" \
  --out experimental-prometheus-rw \
  --summary-export "$RUN_DIR/summary-export.json" \
  "$ROOT/cutover-read.js" 2>&1 | tee -a "$LOG"

K6_EXIT_CODE=${PIPESTATUS[0]}
set -e

echo "k6 exit code: $K6_EXIT_CODE" | tee -a "$LOG"

if [[ -f "$RUN_DIR/summary-export.json" ]]; then
  jq -r '
    .metrics
    | to_entries[]
    | select(.value.thresholds != null)
    | "\(.key): \(.value.thresholds)"
  ' "$RUN_DIR/summary-export.json" | tee -a "$LOG"
fi

echo "Results directory: $RUN_DIR"
exit "$K6_EXIT_CODE"
