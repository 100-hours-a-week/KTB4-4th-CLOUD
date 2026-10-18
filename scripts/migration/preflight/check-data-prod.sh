#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_prod_common.sh"
# Intentionally FAIL CLOSED. This package does not contain the original database
# schema-specific checks or SSM tunnel settings. A green Prod migration preflight
# must include verified MySQL and PostgreSQL data/structure reconciliation.
fail 'Data reconciliation' 'NOT IMPLEMENTED: integrate verified Prod MySQL and PostgreSQL SQL-level checks before allowing PASS/Cutover'
