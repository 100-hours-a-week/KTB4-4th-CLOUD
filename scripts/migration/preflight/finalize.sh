#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../common/common.sh"

failed="$(awk -F '\t' '$2 == "FAIL" {count++} END {print count+0}' "$CHECKS_TSV")"
passed="$(awk -F '\t' '$2 == "PASS" {count++} END {print count+0}' "$CHECKS_TSV")"
result=PASS; [[ "$failed" == 0 ]] || result=FAIL
completed_at="$(TZ=Asia/Seoul date +'%Y-%m-%d %H:%M:%S KST')"

jq -Rn --arg result "$result" --arg completed_at "$completed_at" --argjson passed "$passed" --argjson failed "$failed" '
  [inputs | split("\t") | {name:.[0],status:.[1],detail:.[2]}] as $checks
  | {result:$result,completed_at:$completed_at,passed:$passed,failed:$failed,checks:$checks}
' < "$CHECKS_TSV" > "$PREFLIGHT_RESULT_DIR/summary.json"

{
  echo "## Staging Migration Preflight 결과"
  echo
  echo "- 결과: **$result**"
  echo "- 완료: \`$completed_at\`"
  echo "- PASS: $passed / FAIL: $failed"
  echo
  echo "| 검증 | 결과 | 상세 |"
  echo "|---|---:|---|"
  awk -F '\t' '{printf "| %s | %s | %s |\n", $1, $2, $3}' "$CHECKS_TSV"
} >> "${GITHUB_STEP_SUMMARY:-/dev/stdout}"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "result=$result" >> "$GITHUB_OUTPUT"
  echo "completed_at=$completed_at" >> "$GITHUB_OUTPUT"
  echo "dms_task_arn=$(cat "$PREFLIGHT_RESULT_DIR/dms-task-arn" 2>/dev/null || true)" >> "$GITHUB_OUTPUT"
fi
[[ "$result" == PASS ]]
