#!/usr/bin/env bash
set -euo pipefail

# Run on the existing Amazon Linux 2023 SSM bastion as root.
kubectl_url="https://s3.us-west-2.amazonaws.com/amazon-eks/1.33.13/2026-07-05/bin/linux/amd64/kubectl"
helm_version="v3.22.0"
helm_archive="helm-${helm_version}-linux-amd64.tar.gz"
helm_url="https://get.helm.sh/${helm_archive}"
work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

curl --fail --location --silent --show-error "$kubectl_url" --output "$work_dir/kubectl"
curl --fail --location --silent --show-error "${kubectl_url}.sha256" --output "$work_dir/kubectl.sha256"
printf '%s  %s\n' "$(awk '{print $1}' "$work_dir/kubectl.sha256")" "$work_dir/kubectl" | sha256sum --check --status
install -m 0755 "$work_dir/kubectl" /usr/local/bin/kubectl

curl --fail --location --silent --show-error "$helm_url" --output "$work_dir/$helm_archive"
curl --fail --location --silent --show-error "${helm_url}.sha256sum" --output "$work_dir/${helm_archive}.sha256sum"
printf '%s  %s\n' "$(awk '{print $1}' "$work_dir/${helm_archive}.sha256sum")" "$work_dir/$helm_archive" | sha256sum --check --status
tar -xzf "$work_dir/$helm_archive" -C "$work_dir" linux-amd64/helm
install -m 0755 "$work_dir/linux-amd64/helm" /usr/local/bin/helm

/usr/local/bin/kubectl version --client
/usr/local/bin/helm version --short
