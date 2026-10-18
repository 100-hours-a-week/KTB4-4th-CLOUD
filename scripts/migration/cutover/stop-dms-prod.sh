#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/prod-common.sh"
: "${DMS_TASK_ARN:?}"
[[ "${DMS_STOP_APPROVED:-}" == YES ]] || die 'Explicit DMS stop approval required'
[[ "${GATE_VERIFIED:-}" == YES && "${TRANSACTIONS_VERIFIED:-}" == YES && "${CDC_VERIFIED:-}" == YES ]] || die 'Gate/transaction/CDC proof missing'
require_account
bash scripts/migration/cutover/stop-dms.sh
log 'DMS stopped; rollback now requires a separate data recovery plan.'
