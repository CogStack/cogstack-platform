#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
install_k3s="${INSTALL_K3S:-true}"
helm_version="${HELM_VERSION:-v4.3.1}"
k3s_version="${K3S_VERSION:-v1.37.2+k3s1}"

case "$install_k3s" in
    true|false) ;;
    *) echo "INSTALL_K3S must be true or false." >&2; exit 1 ;;
esac

if [ "$install_k3s" = "true" ]; then
    if [[ ! "$helm_version" =~ ^v4\.[0-9]+\.[0-9]+$ ]]; then
        echo "HELM_VERSION must be a Helm 4 release such as v4.3.1." >&2
        exit 1
    fi
    if [[ ! "$k3s_version" =~ ^v1\.[0-9]+\.[0-9]+\+k3s[0-9]+$ ]]; then
        echo "K3S_VERSION must be a K3s release such as v1.37.2+k3s1." >&2
        exit 1
    fi
fi

if [ "$(id -u)" -eq 0 ]; then
    echo "Running with root privileges."
else
    echo "This script installs system packages and may prompt for sudo privileges."
    sudo -v
fi

os_distribution="$(bash "${script_dir}/detect_os.sh")"

echo "Found distribution: $os_distribution "

bash "${script_dir}/install_host_utils.sh"
bash "${script_dir}/install_docker.sh"

if [ "$install_k3s" = "true" ]; then
    bash "${script_dir}/install_k3s.sh"
    bash "${script_dir}/install_helm.sh"
fi

echo "Finished installing Docker and utilities."
