
#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/prod-common.sh"

: "${AWS_REGION:=ap-northeast-2}"
: "${PROD_ALB_NAME:=needu-prod-alb}"
: "${EVIDENCE_DIR:=./migration-evidence}"

mkdir -p "$EVIDENCE_DIR"

require_account

alb_arn="$(aws elbv2 describe-load-balancers \
  --region "$AWS_REGION" \
  --names "$PROD_ALB_NAME" \
  --query 'LoadBalancers[0].LoadBalancerArn' \
  --output text)"

listener_arn="$(aws elbv2 describe-listeners \
  --region "$AWS_REGION" \
  --load-balancer-arn "$alb_arn" \
  --query 'Listeners[?Port==`443`].ListenerArn | [0]' \
  --output text)"

[[ -n "$listener_arn" && "$listener_arn" != "None" ]] ||
  die "Prod HTTPS listener not found"

rules_json="$(aws elbv2 describe-rules \
  --region "$AWS_REGION" \
  --listener-arn "$listener_arn" \
  --output json)"

printf '%s\n' "$rules_json" \
  > "$EVIDENCE_DIR/prod-alb-write-gate-rules.json"

jq -e '
  def values($field; $config):
    [.Conditions[]
      | select(.Field == $field)
      | .[$config].Values[]
    ];

  def regex_values($field; $config):
    [.Conditions[]
      | select(.Field == $field)
      | (.[$config].RegexValues // [])[]
    ];

  def is503:
    any(.Actions[];
      .Type == "fixed-response"
      and .FixedResponseConfig.StatusCode == "503"
    );

  [.Rules[] | select(.Priority == "1")] as $method
  | [.Rules[] | select(.Priority == "2")] as $callback

  | ($method | length) == 1
  and ($callback | length) == 1

  and (
    $method[0]
    | is503
      and (
        regex_values("host-header"; "HostHeaderConfig")
      ) == ["^(prod\\.)?needu\\.gift$"]
      and (
        values("http-request-method"; "HttpRequestMethodConfig") | sort
      ) == (["POST", "PUT", "PATCH", "DELETE"] | sort)
      and (
        [.Conditions[] | .Field] | sort
      ) == (["host-header", "http-request-method"] | sort)
  )

  and (
    $callback[0]
    | is503
      and (
        values("host-header"; "HostHeaderConfig") | sort
      ) == (["needu.gift", "prod.needu.gift"] | sort)
      and (
        values("path-pattern"; "PathPatternConfig") | sort
      ) == (
        [
          "/api/v1/auth/csrf",
          "/api/v1/auth/kakao/*",
          "/api/v1/friends/kakao/*"
        ] | sort
      )
      and (
        [.Conditions[] | .Field] | sort
      ) == (["host-header", "path-pattern"] | sort)
  )
' <<< "$rules_json" >/dev/null ||
  die "Prod ALB Write Gate conditions do not match the approved configuration"

echo "[PASS] Prod ALB Write Gate configuration"
echo "[PASS] Priority 1: POST/PUT/PATCH/DELETE -> 503"
echo "[PASS] Priority 2: CSRF/Kakao callback paths -> 503"
echo "[PASS] Both production hosts covered"

log "ALB Write Gate verified using read-only AWS API"
