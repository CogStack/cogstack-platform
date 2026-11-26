#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
install_k3s="${INSTALL_K3S:-true}"

case "$install_k3s" in
    true|false) ;;
    *) echo "INSTALL_K3S must be true or false." >&2; exit 1 ;;
esac

if [ "$(id -u)" -eq 0 ]; then
    echo "Running with root privileges."
else
    echo "This script installs system packages and may prompt for sudo privileges."
    sudo -v
fi

os_distribution="$(bash "${script_dir}/detect_os.sh")"

echo "Found distribution: $os_distribution "

bash "${script_dir}/install_host_utils.sh"

if ! keytool -help >/dev/null 2>&1; then
    echo "Java keytool could not run after JDK installation." >&2
    exit 1
fi

bash "${script_dir}/install_docker.sh"

if [ "$install_k3s" = "true" ]; then
    bash "${script_dir}/install_k3s.sh"
    bash "${script_dir}/install_helm.sh"
fi

echo "Finished installing Docker and utilities."
