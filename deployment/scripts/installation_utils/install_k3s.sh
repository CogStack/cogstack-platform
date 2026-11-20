#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
k3s_version="${K3S_VERSION:-v1.37.2+k3s1}"

if [[ ! "$k3s_version" =~ ^v1\.[0-9]+\.[0-9]+\+k3s[0-9]+$ ]]; then
    echo "K3S_VERSION must be a K3s release such as v1.37.2+k3s1." >&2
    exit 1
fi

bash "${script_dir}/detect_os.sh" > /dev/null
installer_temp_dir="$(mktemp -d)"
trap 'rm -rf "$installer_temp_dir"' EXIT

echo "Installing K3s ${k3s_version}..."
k3s_installer="${installer_temp_dir}/install-k3s.sh"
curl -fsSL https://get.k3s.io -o "$k3s_installer"
# Install the binary and service without starting a cluster. K3s provides kubectl.
sudo env INSTALL_K3S_VERSION="$k3s_version" \
    INSTALL_K3S_SKIP_ENABLE=true INSTALL_K3S_SKIP_START=true \
    sh "$k3s_installer" server
k3s --version
echo "K3s installed. Its service is not automatically enabled or started."
