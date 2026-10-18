
#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/_prod_common.sh"

CHECK="DNS"
DNS_PHASE="${DNS_PHASE:-before}"

for v in \
  HOSTED_ZONE_ID \
  LIVE_HOST \
  PROD_HOST \
  V1_EIP \
  V1_INSTANCE_ID \
  ALB_NAME \
  PREFLIGHT_RESULT_DIR
do
  need "$v" "$CHECK"
done

case "$DNS_PHASE" in
  before|after) ;;
  *) fail "$CHECK" "Invalid DNS_PHASE: $DNS_PHASE (before|after)" ;;
esac

mkdir -p "$PREFLIGHT_RESULT_DIR"

# 1. Route53 레코드 조회
records="$(aws route53 list-resource-record-sets \
  --hosted-zone-id "$HOSTED_ZONE_ID" \
  --output json)" || fail "$CHECK" 'Route53 lookup failed'

# 2. Prod ALB 정보 조회
alb_info="$(aws elbv2 describe-load-balancers \
  --names "$ALB_NAME" \
  --output json)" || fail "$CHECK" 'Prod ALB lookup failed'

alb_dns="$(jq -r '.LoadBalancers[0].DNSName // empty' <<< "$alb_info")"
alb_zone="$(jq -r '.LoadBalancers[0].CanonicalHostedZoneId // empty' <<< "$alb_info")"

[[ -n "$alb_dns" && -n "$alb_zone" ]] \
  || fail "$CHECK" 'ALB DNS name or zone ID missing'

# 3. DNS 레코드 추출
live_record="$(jq -c \
  --arg name "${LIVE_HOST}." '
  [.ResourceRecordSets[]
   | select(.Name == $name and .Type == "A")]
  | if length == 1 then .[0] else empty end
' <<< "$records")"

prod_record="$(jq -c \
  --arg name "${PROD_HOST}." '
  [.ResourceRecordSets[]
   | select(.Name == $name and .Type == "A")]
  | if length == 1 then .[0] else empty end
' <<< "$records")"

[[ -n "$live_record" ]] \
  || fail "$CHECK" 'Live A record missing or duplicated'

[[ -n "$prod_record" ]] \
  || fail "$CHECK" 'Prod A record missing or duplicated'

# 4. Prod 도메인은 항상 ALB Alias
jq -e \
  --arg dns "$alb_dns" \
  --arg zone "$alb_zone" '
  (.AliasTarget.DNSName // "" | rtrimstr(".")) == $dns
  and .AliasTarget.HostedZoneId == $zone
' <<< "$prod_record" >/dev/null \
  || fail "$CHECK" 'prod.needu.gift ALB Alias mismatch'

echo "[PASS] $PROD_HOST -> Prod ALB"

# 5. V1 EIP 연결 상태 확인
eip_instance="$(aws ec2 describe-addresses \
  --filters "Name=public-ip,Values=$V1_EIP" \
  --query 'Addresses[0].InstanceId' \
  --output text)" || fail "$CHECK" 'V1 EIP lookup failed'

[[ "$eip_instance" == "$V1_INSTANCE_ID" ]] \
  || fail "$CHECK" "V1 EIP attached to unexpected instance: $eip_instance"

echo "[PASS] V1 EIP -> EC2 $V1_INSTANCE_ID"

# 6. 단계별 운영 DNS 검증
if [[ "$DNS_PHASE" == "before" ]]; then

  jq -e --arg ip "$V1_EIP" '
    (has("AliasTarget") | not)
    and .TTL == 300
    and .ResourceRecords == [{"Value": $ip}]
  ' <<< "$live_record" >/dev/null \
    || fail "$CHECK" "Before phase: $LIVE_HOST must point to V1 EIP"

  echo "[PASS] BEFORE: $LIVE_HOST -> V1 EIP $V1_EIP"

else

  jq -e \
    --arg dns "$alb_dns" \
    --arg zone "$alb_zone" '
    (.AliasTarget.DNSName // "" | rtrimstr(".")) == $dns
    and .AliasTarget.HostedZoneId == $zone
  ' <<< "$live_record" >/dev/null \
    || fail "$CHECK" "After phase: $LIVE_HOST must point to Prod ALB"

  echo "[PASS] AFTER: $LIVE_HOST -> Prod ALB"

fi

# 7. 증적 저장
printf '%s\n' "$live_record" \
  > "$PREFLIGHT_RESULT_DIR/live-dns.json"

printf '%s\n' "$prod_record" \
  > "$PREFLIGHT_RESULT_DIR/prod-dns.json"

jq -n \
  --arg phase "$DNS_PHASE" \
  --arg live "$LIVE_HOST" \
  --arg prod "$PROD_HOST" \
  --arg alb "$alb_dns" \
  --arg v1 "$V1_EIP" \
  '{
    phase: $phase,
    live_host: $live,
    prod_host: $prod,
    alb_dns: $alb,
    v1_eip: $v1
  }' > "$PREFLIGHT_RESULT_DIR/dns-summary.json"

pass "$CHECK" "DNS phase=$DNS_PHASE; Route53 records validated"
