#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/prod-common.sh"
: "${V1_INSTANCE_ID:=i-071de18816cfae436}"
require_account
# Reuse the existing proven dual-engine SSM check; it performs two checks five seconds apart.
[[ -f scripts/migration/cutover/check-transactions.sh ]] || die 'Missing existing transaction checker'
V1_INSTANCE_ID="$V1_INSTANCE_ID" AWS_REGION="$AWS_REGION" bash scripts/migration/cutover/check-transactions.sh
log 'MySQL and PostgreSQL active transactions = 0 twice; this is not proof of zero writes.'
