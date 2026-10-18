#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/prod-common.sh"
[[ "${ENABLE_PROD_DNS_CHANGE:-}" == YES ]] || die 'DNS change not enabled'
[[ "${CONFIRM_PHRASE:-}" == "SWITCH needu.gift TO V2" ]] || die 'Explicit confirmation phrase mismatch'
[[ "${DB_CUTOVER_APPROVED:-}" == YES ]] || die 'Database cutover approval missing'
[[ "${V1_WRITE_GATE_VERIFIED:-}" == YES ]] || die 'V1 write gate verification missing'
[[ "${FINAL_DMS_VALIDATED:-}" == YES ]] || die 'Final DMS verification missing'
[[ "${POSTGRES_VALIDATED:-}" == YES ]] || die 'PostgreSQL reconciliation verification missing'
require_account
bash "$(dirname "$0")/check-prod-readiness.sh"
# Capture live A record immediately before mutation, for operator-led recovery.
current="$(get_record "$LIVE_HOST")"
printf '%s\n' "$current" > "$EVIDENCE_DIR/live-before-switch.json"
zone="$(cat "$EVIDENCE_DIR/alb-zone-id.txt")"
change="$(jq -n --arg name "$LIVE_HOST." --arg dns "$PROD_ALB_DNS." --arg zone "$zone" '{Comment:"NeedU V1 to V2 production cutover (approved)",Changes:[{Action:"UPSERT",ResourceRecordSet:{Name:$name,Type:"A",AliasTarget:{HostedZoneId:$zone,DNSName:$dns,EvaluateTargetHealth:false}}}]}')"
printf '%s\n' "$change" > "$EVIDENCE_DIR/dns-change-request.json"
log 'Submitting Route53 UPSERT for needu.gift'
response="$(aws route53 change-resource-record-sets --hosted-zone-id "$HOSTED_ZONE_ID" --change-batch "$change")"
printf '%s\n' "$response" > "$EVIDENCE_DIR/dns-change-response.json"
id="$(jq -r '.ChangeInfo.Id' <<< "$response")"
[[ "$id" == /change/* ]] || die 'Route53 change ID missing'
log "Route53 change submitted: $id"
aws route53 wait resource-record-sets-changed --id "$id"
log 'Route53 reports INSYNC (does not guarantee all client DNS caches refreshed)'
