#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
command -v k6 >/dev/null || { echo 'Install k6 first: brew install k6' >&2; exit 1; }
[[ -f data/users.json ]] || { echo 'Create data/users.json from data/users.example.json' >&2; exit 1; }
mkdir -p results
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "results/$STAMP"
# Each run has an isolated result directory. k6 summary uses relative path.
cd "results/$STAMP"
mkdir -p results
# Keep all outputs for later alignment with T0..T8 (JSONL timestamps are UTC epoch).
k6 run --out "json=metrics.jsonl" --summary-export "summary-export.json" \
  "$ROOT/cutover-read.js" 2>&1 | tee console.log
