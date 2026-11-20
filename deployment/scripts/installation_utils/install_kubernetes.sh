#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
kubernetes_minor_version="${KUBERNETES_MINOR_VERSION:-v1.37}"
helm_version="${HELM_VERSION:-v4.3.1}"

if [[ ! "$kubernetes_minor_version" =~ ^v1\.[0-9]+$ ]]; then
    echo "KUBERNETES_MINOR_VERSION must be a minor release such as v1.37." >&2
    exit 1
fi
if [[ ! "$helm_version" =~ ^v4\.[0-9]+\.[0-9]+$ ]]; then
    echo "HELM_VERSION must be a Helm 4 release such as v4.3.1." >&2
    exit 1
fi

os_distribution="$(bash "${script_dir}/detect_os.sh")"
installer_temp_dir="$(mktemp -d)"
trap 'rm -rf "$installer_temp_dir"' EXIT

echo "Installing Kubernetes ${kubernetes_minor_version} (kubeadm, kubelet, kubectl)..."
kubernetes_repository="https://pkgs.k8s.io/core:/stable:/${kubernetes_minor_version}"

if [ "$os_distribution" = "debian" ] || [ "$os_distribution" = "ubuntu" ]; then
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL "${kubernetes_repository}/deb/Release.key" | \
        sudo gpg --batch --yes --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    sudo chmod a+r /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] ${kubernetes_repository}/deb/ /" | \
        sudo tee /etc/apt/sources.list.d/kubernetes.list > /dev/null
    sudo apt-get update -y
    sudo apt-get install -y kubelet kubeadm kubectl
    # Cluster upgrades must be coordinated with kubeadm, not unattended upgrades.
    sudo apt-mark hold kubelet kubeadm kubectl
else
    sudo tee /etc/yum.repos.d/kubernetes.repo > /dev/null <<EOF
[kubernetes]
name=Kubernetes
baseurl=${kubernetes_repository}/rpm/
enabled=1
gpgcheck=1
gpgkey=${kubernetes_repository}/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF
    sudo yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
fi

# kubeadm init/join configures and starts kubelet when the node's role is chosen.
sudo systemctl enable kubelet.service

echo "Installing Helm ${helm_version}..."
helm_installer="${installer_temp_dir}/get-helm-4"
curl -fsSL "https://raw.githubusercontent.com/helm/helm/${helm_version}/scripts/get-helm-4" -o "$helm_installer"
# The official installer verifies the release archive's checksum by default.
sudo bash "$helm_installer" --version "$helm_version"

kubectl version --client
helm version --short
echo "Kubernetes tools installed. Prepare containerd CRI, swap and networking before kubeadm init/join."
echo "See deploy/kubernetes/README.md for cluster setup and deployment steps."
