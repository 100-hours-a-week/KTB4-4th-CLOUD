#!/usr/bin/env bash
set -euo pipefail
# Legacy final-cutover DNS mutation intentionally disabled.
echo '::error::DNS must be pre-switched via a separate approved operation while ALB V1=100. This legacy final-cutover command is disabled.' >&2
exit 1
