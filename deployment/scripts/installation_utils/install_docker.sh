#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
target_user="${SUDO_USER:-${USER:-$(id -un)}}"
os_distribution="$(bash "${script_dir}/detect_os.sh")"

if [ "$os_distribution" == "debian" ] || [ "$os_distribution" == "ubuntu" ];
then
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL "https://download.docker.com/linux/${os_distribution}/gpg" | sudo gpg --batch --yes --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    # shellcheck disable=SC1091 # Standard OS metadata file provided by Debian/Ubuntu.
    docker_codename="$(. /etc/os-release && printf '%s' "$VERSION_CODENAME")"
    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${os_distribution} \
    ${docker_codename} stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt -y update
    sudo apt -y upgrade
    sudo apt -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

elif  [ "$os_distribution" == "redhat" ] || [ "$os_distribution" == "red hat" ];
then
    sudo yum remove -y docker \
                    docker-client \
                    docker-client-latest \
                    docker-common \
                    docker-latest \
                    docker-latest-logrotate \
                    docker-logrotate \
                    docker-engine

    sudo yum remove -y buildah podman

    sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    sudo yum-config-manager --enable docker-ce-stable
    sudo yum-config-manager --enable docker-ce-stable-source
    sudo yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

else
    echo "No instructions given for distribution: $os_distribution" >&2
    exit 1
fi

sudo groupadd -f docker
sudo usermod -aG docker root
if [ -n "$target_user" ] && [ "$target_user" != "root" ] && id "$target_user" >/dev/null 2>&1; then
    sudo usermod -aG docker "$target_user"
fi

sudo systemctl enable docker.service
sudo systemctl start docker

if [ "$os_distribution" == "debian" ] || [ "$os_distribution" == "ubuntu" ]; then
    sudo apt-get -y autoremove
else
    sudo yum -y autoremove
fi

sudo sysctl -w vm.max_map_count=262144

sudo sh -c "echo 'vm.max_map_count=262144' >> /etc/sysctl.conf"
sudo sysctl -p
