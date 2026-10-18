#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/prod-common.sh"
: "${V1_INSTANCE_ID:=i-071de18816cfae436}"
[[ "${GATE_ACTION:-}" == ENABLE ]] || die 'GATE_ACTION=ENABLE required'
require_account
# SSM executes only the known, already provisioned nginx config. No arbitrary upload.
remote='set -euo pipefail
link=/etc/nginx/sites-enabled/needu
normal=/etc/nginx/sites-available/needu-normal
readonly=/etc/nginx/sites-available/needu-readonly
[ -f "$normal" ] && [ -f "$readonly" ]
previous=$(readlink -f "$link")
[ "$previous" = "$normal" ] || [ "$previous" = "$readonly" ] || exit 21
sudo nginx -t >/dev/null 2>&1
if [ "$previous" = "$normal" ]; then
  sudo ln -sfn "$readonly" "$link"
  if ! sudo nginx -t || ! sudo systemctl reload nginx; then
    sudo ln -sfn "$normal" "$link"
    sudo nginx -t && sudo systemctl reload nginx || true
    exit 22
  fi
fi
[ "$(readlink -f "$link")" = "$readonly" ]
echo GATE_LINK_READONLY=PASS'
encoded=$(printf '%s' "$remote" | base64 | tr -d '\n')
cmd="printf %s '$encoded' | base64 -d | bash"
id=$(aws ssm send-command --region "$AWS_REGION" --instance-ids "$V1_INSTANCE_ID" --document-name AWS-RunShellScript --parameters "$(jq -cn --arg cmd "$cmd" '{commands:[$cmd]}')" --query Command.CommandId --output text)
log "SSM command id: $id"; printf '%s\n' "$id" > "$EVIDENCE_DIR/gate-ssm-command-id.txt"
for _ in {1..30}; do
 status=$(aws ssm get-command-invocation --region "$AWS_REGION" --command-id "$id" --instance-id "$V1_INSTANCE_ID" --query Status --output text 2>/dev/null || true)
 case "$status" in
 Success) break;; Failed|Cancelled|TimedOut|Cancelling) die "Gate SSM failed: $status";; esac
 sleep 3
done
[[ "${status:-}" == Success ]] || die 'Gate SSM timeout'
output=$(aws ssm get-command-invocation --region "$AWS_REGION" --command-id "$id" --instance-id "$V1_INSTANCE_ID" --query StandardOutputContent --output text)
grep -qx 'GATE_LINK_READONLY=PASS' <<< "$output" || die 'Gate verification marker missing'
log 'Nginx readonly gate enabled. DO NOT release until separately approved.'
