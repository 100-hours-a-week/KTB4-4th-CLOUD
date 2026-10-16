#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PHASE="${1:-}"
case "$PHASE" in T-2|T-1|T0|T1|T2|T3|T4|T5|T6|T7|T8) ;; *) echo 'Usage: mark-phase.sh T0..T8 [description] [run-directory]' >&2; exit 1 ;; esac
NOTE="${2:-}"
RUN_DIR="${3:-$ROOT/results}"
mkdir -p "$RUN_DIR"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
# TSV avoids shell JSON escaping problems; phase events can be imported into Grafana separately.
printf '%s\t%s\t%s\n' "$TS" "$PHASE" "$NOTE" | tee -a "$RUN_DIR/phases.tsv"
