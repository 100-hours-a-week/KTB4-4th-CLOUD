
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PHASE="${1:-}"
NOTE="${2:-}"
RUN_DIR="${3:-$ROOT/results}"

# 허용하는 이벤트
case "$PHASE" in
  T-2|T-1|T0|T1|T2|T3|T4|T5|T6|T7|T8|T9|T10)
    ;;
  *)
    echo "Usage: $0 T-2|T-1|T0..T10 [description] [run-directory]" >&2
    exit 1
    ;;
esac

mkdir -p "$RUN_DIR"

# UTC: Grafana, Prometheus 등과 시각 비교용
TS_UTC="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

# KST: 리허설 담당자가 읽기 쉬운 시각
TS_KST="$(TZ=Asia/Seoul date '+%Y-%m-%d %H:%M:%S KST')"

PHASE_FILE="$RUN_DIR/phases.tsv"

# 기존 TSV 형식 유지: UTC, Phase, Description
printf '%s\t%s\t%s\n' \
  "$TS_UTC" \
  "$PHASE" \
  "$NOTE" >> "$PHASE_FILE"

echo "========================================"
echo "Migration Phase Recorded"
echo "========================================"
echo "Phase : $PHASE"
echo "UTC   : $TS_UTC"
echo "KST   : $TS_KST"
echo "Event : $NOTE"
echo "File  : $PHASE_FILE"
echo "========================================"
