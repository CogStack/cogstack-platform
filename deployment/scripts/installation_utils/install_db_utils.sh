#!/usr/bin/env bash

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=installation_helpers.sh
source "${script_dir}/installation_helpers.sh"

if [ "$(id -u)" -eq 0 ]; then
    echo "Running with root privileges."
else
    echo "This script installs system packages and may prompt for sudo privileges."
    sudo -v
fi

os_distribution="$(bash "${script_dir}/detect_os.sh")"
echo "Found distribution: $os_distribution "

if [ "$os_distribution" == "debian" ] || [ "$os_distribution" == "ubuntu" ];
then
    install_missing_packages "$os_distribution" postgresql-client
elif  [ "$os_distribution" == "redhat" ];
then
    install_missing_packages "$os_distribution" postgresql
else
    echo "No instructions given for distribution: $os_distribution" 
    exit 1
fi;

echo "Finished installing database utilities.."
