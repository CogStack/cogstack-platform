# Deployment scripts

Run commands from the repository root. Requires Make, Bash, `sudo`, systemd and network
access. Installation and cluster setup invoke `sudo` internally; run setup as the user who will
use `kubectl`.

## Install, initialize and verify

Install on every machine before creating or joining a cluster:

```bash
make -C deployment setup-install-pre-requisites
```

By default, this installs host utilities, Docker, K3s and Helm. **New K3s installations
remain stopped until cluster setup.** Installers skip existing system and Python
packages, Azure CLI, K3s and Helm, and reuse existing Docker and Azure apt sources
(`.list` or `.sources`, including custom filenames). They do not run system upgrades
or autoremove. Installing missing Docker packages on RHEL may remove conflicting
container packages; review the scripts before running on an existing host.
Start a new login session to use Docker without sudo.

On the first machine, initialize the cluster and check it:

```bash
make -C deployment setup-k3s-cluster-init
make -C deployment setup-verify
```

Setup enables/restarts K3s and defaults to Secrets encryption at rest on servers.
Verification checks Docker and K3s without sudo. Expect the node to become `Ready`.

## Expand to three servers

On the first machine, read the join token:

```bash
sudo cat /var/lib/rancher/k3s/server/token
```

After installation on machines 2 and 3, run this on each, replacing
`FIRST_SERVER_IP` and `SERVER_TOKEN`:

```bash
bash deployment/scripts/installation_utils/setup_kubernetes_cluster.sh k3s server \
  --server https://FIRST_SERVER_IP:6443 --token 'SERVER_TOKEN'
```

Run the verification commands above again after joining both servers. For
worker-only nodes, use `agent` instead of `server`. See the
[K3s HA guide](https://docs.k3s.io/datastore/ha-embedded) for availability and
networking requirements.

## kubectl access

Server setup creates `~/.kube/config` with mode `0600` if absent and preserves an
existing file. K3s's bundled kubectl defaults to `/etc/rancher/k3s/k3s.yaml`; use
the printed `--kubeconfig` command to select the intended configuration.

To configure access to an existing cluster without restarting K3s:

```bash
bash deployment/scripts/installation_utils/setup_kubernetes_cluster.sh kubeconfig /etc/rancher/k3s/k3s.yaml
```

## Options and individual utilities

| Variable | Default | Purpose |
| --- | --- | --- |
| `INSTALL_K3S` | `true` | Install K3s and Helm; `false` skips both. |

Individual installers can also be run with `bash`:
[host utilities](installation_utils/install_host_utils.sh),
[Docker](installation_utils/install_docker.sh),
[K3s](installation_utils/install_k3s.sh),
[Helm](installation_utils/install_helm.sh) and
[PostgreSQL clients](installation_utils/install_db_utils.sh).
On a new host, install host utilities first.
[Docker configuration examples](installation_utils/docker_installation_settings/README.md)
are optional and are not applied automatically.

## Dependency audits

Requires `uv`, `pip-audit` and network access. Audits locked dependencies without
changing lockfiles; failures return a nonzero exit status.

```bash
# Documentation dependencies
bash deployment/scripts/maintenance/audit_pip_dependency.sh

# Include NiFi runtime and development dependencies
bash deployment/scripts/maintenance/audit_pip_dependency.sh --include-nifi
```

Use `--help` for available options.
