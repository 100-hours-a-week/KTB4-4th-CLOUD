
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

command -v k6 >/dev/null || {
  echo "Install k6 first: brew install k6" >&2
  exit 1
}

command -v python3 >/dev/null || {
  echo "python3 is required" >&2
  exit 1
}

[[ -f data/users.json ]] || {
  echo "Create data/users.json from data/users.example.json" >&2
  exit 1
}

python3 - <<'PY'
import json
from pathlib import Path

users = json.loads(
    Path("data/users.json").read_text(encoding="utf-8")
)

if not isinstance(users, list) or len(users) != 20:
    raise SystemExit(
        "ERROR: data/users.json must contain exactly 20 accounts"
    )

tokens = []

for index, user in enumerate(users, start=1):
    if not isinstance(user, dict):
        raise SystemExit(f"ERROR: User {index} is invalid")

    for field in ("token", "friendUserId", "giftUserId"):
        value = user.get(field)

        if value is None or not str(value).strip():
            raise SystemExit(
                f"ERROR: User {index} missing {field}"
            )

    token = user["token"]

    if (
        not isinstance(token, str)
        or token.startswith("REPLACE_WITH_")
    ):
        raise SystemExit(
            f"ERROR: Invalid JWT for user {index}"
        )

    tokens.append(token)

if len(set(tokens)) != len(tokens):
    raise SystemExit("ERROR: Duplicate JWT detected")

print(f"Validated test accounts: {len(users)}")
PY

export K6_PROMETHEUS_RW_SERVER_URL="${K6_PROMETHEUS_RW_SERVER_URL:-http://localhost:9090/api/v1/write}"
export K6_PROMETHEUS_RW_TREND_STATS="${K6_PROMETHEUS_RW_TREND_STATS:-p(95)}"

export BASE_URL="${BASE_URL:-https://v1.needu.gift}"
export RATE="${RATE:-10}"
export DURATION="${DURATION:-20m}"
export VUS="${VUS:-30}"
export MAX_VUS="${MAX_VUS:-100}"

mkdir -p results

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
RUN_DIR="$ROOT/results/$STAMP"

mkdir -p "$RUN_DIR/results"

echo "========================================"
echo "NeedU V1 → V2 Cutover k6 Test"
echo "========================================"
echo "Started at (UTC): $STAMP"
echo "Base URL: $BASE_URL"
echo "Test accounts: 20"
echo "Rate: $RATE RPS"
echo "Duration: $DURATION"
echo "VUs: $VUS"
echo "Max VUs: $MAX_VUS"
echo "Iterations: ${ITERATIONS:-arrival-rate mode}"
echo "Prometheus URL: $K6_PROMETHEUS_RW_SERVER_URL"
echo "Results: $RUN_DIR"
echo "========================================"

cd "$RUN_DIR"

k6 run \
  --out "json=metrics.jsonl" \
  --out experimental-prometheus-rw \
  --summary-export "summary-export.json" \
  "$ROOT/cutover-read.js" 2>&1 | tee console.log
