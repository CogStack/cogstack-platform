#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "${script_dir}/detect_os.sh" > /dev/null
installer_temp_dir="$(mktemp -d)"
trap 'rm -rf "$installer_temp_dir"' EXIT

echo "Installing the latest K3s release..."
k3s_installer="${installer_temp_dir}/install-k3s.sh"
curl -fsSL https://get.k3s.io -o "$k3s_installer"
# Install the binary and service without starting a cluster. K3s provides kubectl.
sudo env -u INSTALL_K3S_VERSION INSTALL_K3S_CHANNEL=latest \
    INSTALL_K3S_SKIP_ENABLE=true INSTALL_K3S_SKIP_START=true \
    sh "$k3s_installer" server --secrets-encryption
k3s --version
echo "K3s installed. Its service is not automatically enabled or started."
