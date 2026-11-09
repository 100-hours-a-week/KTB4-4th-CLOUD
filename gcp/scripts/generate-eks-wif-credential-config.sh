#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/../.." && pwd)"
terraform_dir="${repo_root}/gcp/environments/dev"
output_file="${1:-${terraform_dir}/credential-configuration.json}"

if ! command -v terraform >/dev/null 2>&1; then
  echo "terraform is required" >&2
  exit 1
fi

if ! command -v gcloud >/dev/null 2>&1; then
  echo "gcloud is required" >&2
  exit 1
fi

provider="$(terraform -chdir="${terraform_dir}" output -raw workload_identity_provider)"
service_account="$(terraform -chdir="${terraform_dir}" output -raw vertex_invoker_service_account)"

mkdir -p "$(dirname "${output_file}")"
gcloud iam workload-identity-pools create-cred-config "${provider}" \
  --service-account="${service_account}" \
  --credential-source-file=/var/run/service-account/token \
  --credential-source-type=text \
  --output-file="${output_file}"

echo "Created non-secret external-account credential configuration: ${output_file}"
