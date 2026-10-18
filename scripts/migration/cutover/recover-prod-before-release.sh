#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/prod-common.sh"
log 'Starting automatic pre-release recovery: ALB -> V1, then Write Gate OFF'
ALLOW_RECOVERY_WITHOUT_GATE=YES CUTOVER_TARGET=v1 bash scripts/migration/cutover/switch-alb-prod.sh
GATE_ACTION=disable bash scripts/migration/cutover/manage-write-gate-prod.sh
log 'Recovery completed. DMS remains stopped and must not be restarted without a data recovery decision.'
