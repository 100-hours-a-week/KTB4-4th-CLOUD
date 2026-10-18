#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/prod-common.sh"
require_account
current="$(get_record "$LIVE_HOST")"
require_single_record "$current"
jq -e --arg dns "$PROD_ALB_DNS" '(.AliasTarget.DNSName|rtrimstr("."))==$dns' <<< "$current" >/dev/null || die 'Live DNS is not V2 ALB alias'
printf '%s\n' "$current" > "$EVIDENCE_DIR/live-after.json"
log 'Route53 authoritative record now points to V2 ALB'
log 'NOTE: old V1 clients may continue to write during DNS caching; keep V1 gate active'
