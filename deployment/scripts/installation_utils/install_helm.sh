#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "${script_dir}/detect_os.sh" > /dev/null
installer_temp_dir="$(mktemp -d)"
trap 'rm -rf "$installer_temp_dir"' EXIT

echo "Installing the latest Helm release..."
helm_installer="${installer_temp_dir}/get-helm-4"
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4 -o "$helm_installer"
sudo env -u DESIRED_VERSION bash "$helm_installer"

helm version --short
