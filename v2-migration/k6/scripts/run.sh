
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

command -v k6 >/dev/null || {
  echo 'Install k6 first: brew install k6' >&2
  exit 1
}

[[ -f data/users.json ]] || {
  echo 'Create data/users.json from data/users.example.json' >&2
  exit 1
}

# Prometheus Remote Write configuration
export K6_PROMETHEUS_RW_SERVER_URL="${K6_PROMETHEUS_RW_SERVER_URL:-http://localhost:9090/api/v1/write}"
export K6_PROMETHEUS_RW_TREND_STATS="${K6_PROMETHEUS_RW_TREND_STATS:-p(95)}"

# Each run has an isolated result directory.
mkdir -p results
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "results/$STAMP"

cd "results/$STAMP"
mkdir -p results

echo "========================================"
echo "NeedU V1 → V2 Cutover k6 Test"
echo "========================================"
echo "Started at (UTC): $STAMP"
echo "Prometheus URL: $K6_PROMETHEUS_RW_SERVER_URL"
echo "Results: $ROOT/results/$STAMP"
echo "========================================"

# Keep all outputs for later alignment with T0..T8.
# JSONL timestamps are UTC epoch.
# Send metrics to Prometheus Remote Write simultaneously.
k6 run \
  --out "json=metrics.jsonl" \
  --out experimental-prometheus-rw \
  --summary-export "summary-export.json" \
  "$ROOT/cutover-read.js" 2>&1 | tee console.log
