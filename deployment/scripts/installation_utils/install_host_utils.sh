#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
os_distribution="$(bash "${script_dir}/detect_os.sh")"

if [ "$os_distribution" == "debian" ] || [ "$os_distribution" == "ubuntu" ];
then
    sudo apt-get update -y
    sudo apt-get upgrade -y

    # NFS STUFF
    sudo apt-get install -y samba cifs-utils nfs-common nfs-kernel-server archivemount

    # monitoring
    sudo apt-get install -y htop iotop sysstat

    sudo apt-get install -y jq wget curl gnupg gnupg-agent git ca-certificates apt-transport-https python3 python3-pip python3-full openssl libssl-dev zip unzip tar nano gcc make python3-dev build-essential software-properties-common

    echo "Installing Azure CLI..."
    curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

elif  [ "$os_distribution" == "redhat" ] || [ "$os_distribution" == "red hat" ] || [ "$os_distribution" == "centos" ];
then
    sudo yum -y update
    sudo yum -y upgrade

    # NFS STUFF
    sudo yum install -y samba samba-client cifs-utils nfs-utils rpcbind archivemount

    # monitoring
    sudo yum install -y htop iotop sysstat

    # install necessary prerequisites
    sudo yum install -y jq yum-utils wget curl git device-mapper-persistent-data lvm2 python3 python3-pip libffi-devel openssl openssl-devel zip unzip tar nano gcc gcc-c++ make python3-devel libevent-devel

    echo "Installing Azure CLI..."
    sudo rpm --import https://packages.microsoft.com/keys/microsoft-2025.asc
    sudo dnf install -y azure-cli
else
    echo "No instructions given for distribution: $os_distribution" >&2
    exit 1
fi

echo "Installing required Python packages..."

# Keep the distribution's pip; newer releases require an explicit override when
# installing utilities into an externally managed system Python environment.
pip_options=(install html2text jsoncsv detect)
if pip3 install --help | grep -- '--break-system-packages' > /dev/null; then
    pip_options+=(--break-system-packages)
fi
sudo -H pip3 "${pip_options[@]}"
