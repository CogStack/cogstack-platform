#!/usr/bin/env bash

set -euo pipefail

if [ "$#" -eq 0 ]; then
    echo "Usage: $0 [user@]FIRST_SERVER [[user@]SERVER ...]" >&2
    exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
nodes=("$@")
remote_dirs=()

remote() {
    ssh -o BatchMode=no -S none -- "$@"
}

cleanup() {
    for index in "${!remote_dirs[@]}"; do
        remote "${nodes[index]}" "rm -rf -- ${remote_dirs[index]}" || true
    done
}
trap cleanup EXIT

server_token() {
    remote "$1" 'sudo -n bash -s' <<'REMOTE'
set -euo pipefail
if [ -s /var/lib/rancher/k3s/server/token ]; then
    cat /var/lib/rancher/k3s/server/token
elif [ -e /var/lib/rancher/k3s/server ] || [ -e /var/lib/rancher/k3s/agent ]; then
    echo "Existing K3s state has no server token; stopping." >&2
    exit 1
fi
REMOTE
}

for node in "${nodes[@]}"; do
    echo "Installing prerequisites on $node..."
    remote_dir="$(remote "$node" 'sudo -n true && mktemp -d')"
    printf -v remote_dir '%q' "$remote_dir"
    remote_dirs+=("$remote_dir")
    tar -C "$script_dir" -cf - . | remote "$node" "tar -xf - -C $remote_dir"
    remote "$node" "bash $remote_dir/install_os_tools_and_software.sh"
done

token="$(server_token "${nodes[0]}")"
if [ -z "$token" ]; then
    remote "${nodes[0]}" "bash ${remote_dirs[0]}/setup_kubernetes_cluster.sh k3s server --cluster-init"
    token="$(server_token "${nodes[0]}")"
else
    remote "${nodes[0]}" 'sudo -n systemctl start k3s'
fi
if [ -z "$token" ]; then
    echo "K3s server token is unavailable." >&2
    exit 1
fi
if [ "${#nodes[@]}" -gt 1 ]; then
    remote "${nodes[0]}" 'sudo -n test -d /var/lib/rancher/k3s/server/db/etcd' || {
        echo "The first server must use embedded etcd before other servers can join." >&2
        exit 1
    }
fi

server_host="${nodes[0]#*@}"
if [[ "$server_host" == *:* && "$server_host" != \[*\] ]]; then
    server_host="[$server_host]"
fi
printf -v server_url '%q' "https://${server_host}:6443"
for ((index = 1; index < ${#nodes[@]}; index++)); do
    node="${nodes[index]}"
    existing_token="$(server_token "$node")"
    if [ -n "$existing_token" ]; then
        if [ "$existing_token" != "$token" ]; then
            echo "$node belongs to another cluster; stopping." >&2
            exit 1
        fi
        remote "$node" 'sudo -n systemctl start k3s'
    else
        printf '%s\n' "$token" | remote "$node" \
            "IFS= read -r K3S_TOKEN && export K3S_TOKEN && bash ${remote_dirs[index]}/setup_kubernetes_cluster.sh k3s server --server $server_url"
    fi
done

for index in "${!nodes[@]}"; do
    echo "Verifying ${nodes[index]}..."
    remote "${nodes[index]}" \
        "sudo -n install -m 0600 -o \"\$(id -u)\" -g \"\$(id -g)\" /etc/rancher/k3s/k3s.yaml ${remote_dirs[index]}/kubeconfig &&
        bash ${remote_dirs[index]}/verify_docker.sh &&
        KUBECONFIG=${remote_dirs[index]}/kubeconfig bash ${remote_dirs[index]}/verify_k3s.sh"
done
