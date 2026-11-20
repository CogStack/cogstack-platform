#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=installation_helpers.sh
source "${script_dir}/installation_helpers.sh"
target_user="${SUDO_USER:-${USER:-$(id -un)}}"
os_distribution="$(bash "${script_dir}/detect_os.sh")"
missing_docker_packages=()
for package in docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin; do
    if ! package_is_installed "$os_distribution" "$package"; then
        missing_docker_packages+=("$package")
    fi
done

if [ "$os_distribution" == "debian" ] || [ "$os_distribution" == "ubuntu" ];
then
    if [ "${#missing_docker_packages[@]}" -gt 0 ]; then
        if ! apt_repository_exists docker "https://download.docker.com/linux/${os_distribution}"; then
            sudo install -m 0755 -d /etc/apt/keyrings
            if [ ! -s /etc/apt/keyrings/docker.gpg ]; then
                curl -fsSL "https://download.docker.com/linux/${os_distribution}/gpg" | sudo gpg --batch --yes --dearmor -o /etc/apt/keyrings/docker.gpg
            fi
            sudo chmod a+r /etc/apt/keyrings/docker.gpg

            # shellcheck disable=SC1091 # Standard OS metadata file provided by Debian/Ubuntu.
            docker_codename="$(. /etc/os-release && printf '%s' "$VERSION_CODENAME")"
            echo \
            "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${os_distribution} \
            ${docker_codename} stable" | \
            sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        else
            echo "Docker apt repository already exists."
        fi

        install_missing_packages "$os_distribution" "${missing_docker_packages[@]}"
    else
        echo "Docker packages are already installed."
    fi

elif  [ "$os_distribution" == "redhat" ];
then
    if [ "${#missing_docker_packages[@]}" -gt 0 ]; then
        sudo yum remove -y docker docker-client docker-client-latest docker-common \
            docker-latest docker-latest-logrotate docker-logrotate docker-engine buildah podman

        if [ ! -e /etc/yum.repos.d/docker-ce.repo ]; then
            sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            sudo yum-config-manager --enable docker-ce-stable
            sudo yum-config-manager --enable docker-ce-stable-source
        fi

        install_missing_packages "$os_distribution" "${missing_docker_packages[@]}"
    else
        echo "Docker packages are already installed."
    fi

else
    echo "No instructions given for distribution: $os_distribution" >&2
    exit 1
fi

sudo groupadd -f docker
sudo usermod -aG docker root
if [ -n "$target_user" ] && [ "$target_user" != "root" ] && id "$target_user" >/dev/null 2>&1; then
    sudo usermod -aG docker "$target_user"
fi

sudo systemctl enable --now docker.service

sudo sysctl -w vm.max_map_count=262144

sudo sh -c "echo 'vm.max_map_count=262144' >> /etc/sysctl.conf"
sudo sysctl -p
