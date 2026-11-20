#!/usr/bin/env bash

set -euo pipefail

case "${1:-}:${2:-}" in
    k3s:server|k3s:agent|kubeconfig:?*) ;;
    *)
        echo "Usage: $0 k3s server|agent [options] | kubeconfig FILE" >&2
        exit 1
        ;;
esac

backend="$1"
role="$2"
shift 2

case "$backend" in
    k3s)
        if [ "$role" = "server" ]; then
            set -- --secrets-encryption "$@"
        fi
        k3s --version
        installer="$(mktemp)"
        trap 'rm -f "$installer"' EXIT
        curl -fsSL https://get.k3s.io -o "$installer"
        sudo --preserve-env=K3S_TOKEN env INSTALL_K3S_SKIP_DOWNLOAD=true \
            INSTALL_K3S_SKIP_ENABLE=false INSTALL_K3S_SKIP_START=false INSTALL_K3S_FORCE_RESTART=true \
            sh "$installer" "$role" "$@"
        if [ "$role" = "agent" ]; then
            exit 0
        fi
        kubeconfig="/etc/rancher/k3s/k3s.yaml"
        ;;
    kubeconfig)
        if [ "$#" -ne 0 ]; then
            echo "Usage: $0 kubeconfig FILE" >&2
            exit 1
        fi
        kubeconfig="$role"
        ;;
esac

if ! sudo test -r "$kubeconfig"; then
    echo "Kubeconfig unavailable: $kubeconfig. Initialize or start the control plane first." >&2
    exit 1
fi

config_dir="${HOME}/.kube"
config_file="${config_dir}/config"
if [ -e "$config_file" ] || [ -L "$config_file" ]; then
    echo "Existing kubeconfig retained: $config_file"
    echo "Use: sudo kubectl --kubeconfig \"$kubeconfig\" get nodes"
else
    mkdir -p "$config_dir"
    sudo install -m 0600 -o "$(id -u)" -g "$(id -g)" "$kubeconfig" "$config_file"
    echo "Kubeconfig installed: $config_file"
    echo "Use: kubectl --kubeconfig \"$config_file\" get nodes"
fi
