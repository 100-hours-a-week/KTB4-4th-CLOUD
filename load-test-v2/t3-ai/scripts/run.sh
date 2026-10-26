#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ -z "${AI_BASE_URL:-}" ]]; then echo 'Set AI_BASE_URL to the AI server root (not /v1/chat)' >&2; exit 1; fi
if [[ -z "${SERVICE_TOKEN:-}" ]]; then
  read -r -s -p 'AI SERVICE_TOKEN (hidden): ' SERVICE_TOKEN
  echo
  export SERVICE_TOKEN
fi
python3 scripts/run.py
