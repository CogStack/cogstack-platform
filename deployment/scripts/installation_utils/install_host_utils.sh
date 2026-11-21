#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=installation_helpers.sh
source "${script_dir}/installation_helpers.sh"
os_distribution="$(bash "${script_dir}/detect_os.sh")"

if [ "$os_distribution" == "debian" ] || [ "$os_distribution" == "ubuntu" ];
then
    install_missing_packages "$os_distribution" \
        samba cifs-utils nfs-common nfs-kernel-server archivemount \
        htop iotop sysstat \
        jq gettext-base wget curl gnupg gnupg-agent git ca-certificates apt-transport-https python3 python3-pip python3-full openssl libssl-dev zip unzip tar nano gcc make python3-dev build-essential software-properties-common

    if command -v az >/dev/null 2>&1 || package_is_installed "$os_distribution" azure-cli; then
        echo "Azure CLI is already installed."
    elif apt_repository_exists azure-cli https://packages.microsoft.com/repos/azure-cli; then
        install_missing_packages "$os_distribution" azure-cli
    else
        echo "Installing Azure CLI..."
        curl -fsSL https://aka.ms/InstallAzureCLIDeb | sudo bash
    fi

elif  [ "$os_distribution" == "redhat" ];
then
    install_missing_packages "$os_distribution" \
        samba samba-client cifs-utils nfs-utils rpcbind archivemount \
        htop iotop sysstat \
        jq gettext yum-utils wget curl git device-mapper-persistent-data lvm2 python3 python3-pip libffi-devel openssl openssl-devel zip unzip tar nano gcc gcc-c++ make python3-devel libevent-devel

    if command -v az >/dev/null 2>&1 || package_is_installed "$os_distribution" azure-cli; then
        echo "Azure CLI is already installed."
    else
        echo "Installing Azure CLI..."
        sudo rpm --import https://packages.microsoft.com/keys/microsoft-2025.asc
        install_missing_packages "$os_distribution" azure-cli
    fi
else
    echo "No instructions given for distribution: $os_distribution" >&2
    exit 1
fi

missing_python_packages=()
for package in html2text jsoncsv detect; do
    if ! sudo -H pip3 show "$package" >/dev/null 2>&1; then
        missing_python_packages+=("$package")
    fi
done

if [ "${#missing_python_packages[@]}" -gt 0 ]; then
    echo "Installing missing Python packages: ${missing_python_packages[*]}"

    # Keep the distribution's pip; newer releases require an explicit override
    # when installing into an externally managed system Python environment.
    pip_options=(install "${missing_python_packages[@]}")
    if pip3 install --help | grep -- '--break-system-packages' > /dev/null; then
        pip_options+=(--break-system-packages)
    fi
    sudo -H pip3 "${pip_options[@]}"
else
    echo "All required Python packages are already installed."
fi
