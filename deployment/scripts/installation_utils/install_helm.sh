#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
helm_version="${HELM_VERSION:-v4.3.1}"

if [[ ! "$helm_version" =~ ^v4\.[0-9]+\.[0-9]+$ ]]; then
    echo "HELM_VERSION must be a Helm 4 release such as v4.3.1." >&2
    exit 1
fi

bash "${script_dir}/detect_os.sh" > /dev/null
installer_temp_dir="$(mktemp -d)"
trap 'rm -rf "$installer_temp_dir"' EXIT

echo "Installing Helm ${helm_version}..."
helm_installer="${installer_temp_dir}/get-helm-4"
curl -fsSL "https://raw.githubusercontent.com/helm/helm/${helm_version}/scripts/get-helm-4" -o "$helm_installer"
# The official installer verifies the release archive's checksum by default.
sudo bash "$helm_installer" --version "$helm_version"

helm version --short
