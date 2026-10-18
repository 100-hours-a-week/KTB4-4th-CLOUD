#!/usr/bin/env bash
set -euo pipefail
: "${AWS_REGION:=ap-northeast-2}"
: "${EXPECTED_ACCOUNT_ID:=919551759796}"
: "${HOSTED_ZONE_ID:=Z10258582M6TRCEOCUBUW}"
: "${LIVE_HOST:=needu.gift}"
: "${PROD_HOST:=prod.needu.gift}"
: "${V1_EIP:=13.124.155.10}"
: "${PROD_ALB_DNS:=needu-prod-alb-314721872.ap-northeast-2.elb.amazonaws.com}"
: "${PROD_ALB_NAME:=needu-prod-alb}"
: "${EVIDENCE_DIR:=${RUNNER_TEMP:-/tmp}/prod-cutover-evidence}"
mkdir -p "$EVIDENCE_DIR"
log() { printf '[%s] %s\n' "$(TZ=Asia/Seoul date '+%Y-%m-%d %H:%M:%S KST')" "$*"; }
die() { echo "::error::$*" >&2; exit 1; }
require_account() {
  local account
  account="$(aws sts get-caller-identity --query Account --output text)"
  [[ "$account" == "$EXPECTED_ACCOUNT_ID" ]] || die "AWS account mismatch: $account"
}
get_record() {
  aws route53 list-resource-record-sets --hosted-zone-id "$HOSTED_ZONE_ID" --output json \
    | jq -c --arg name "$1." --arg type A '.ResourceRecordSets[] | select(.Name==$name and .Type==$type)'
}
require_single_record() {
  local records="$1" count
  count="$(printf '%s\n' "$records" | grep -c . || true)"
  [[ "$count" == 1 ]] || die "Expected exactly one matching DNS record, got $count"
}
