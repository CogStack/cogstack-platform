# Deployment scripts

Shared utilities for preparing deployment hosts and maintaining this repository.
Run the examples below from the repository root.

| Directory | Purpose |
| --- | --- |
| [`installation_utils/`](installation_utils/) | Install host prerequisites and provide Docker configuration examples. |
| [`maintenance/`](maintenance/) | Audit repository Python dependencies. |

Keep application-specific startup and runtime scripts alongside their applications
under `apps/`.

## Installation utilities

### Prerequisites

The installers recognise Debian, Ubuntu and Red Hat Enterprise Linux.
Package and repository availability depends on the distribution release. They
require Bash, `sudo`, internet access to package repositories and a host using
systemd. They invoke `sudo` internally, including when run as root.

The full installer and database installer update and upgrade system packages.
The Docker installer also changes package repositories, Docker group membership
and system settings; its Red Hat branch removes existing Docker packages,
Podman and Buildah.
Review the script before running it on an existing host.

### Docker and platform tools

[`install_os_tools_and_software.sh`](installation_utils/install_os_tools_and_software.sh)
installs Docker Engine, Buildx, Compose, Azure CLI, Python utilities, filesystem
tools, monitoring tools and build dependencies. By default it also installs
K3s and Helm. K3s supplies kubelet, containerd and kubectl.

It runs the following component scripts, which can also be invoked individually
with `bash`. On a new host, run `install_host_utils.sh` first to install their
prerequisites.

| Script | Purpose |
| --- | --- |
| [`install_host_utils.sh`](installation_utils/install_host_utils.sh) | General packages, filesystem and monitoring tools, Azure CLI and Python utilities. |
| [`install_docker.sh`](installation_utils/install_docker.sh) | Docker Engine, Buildx, Compose, service setup, group membership and system settings. |
| [`install_helm.sh`](installation_utils/install_helm.sh) | Helm for chart deployment. |
| [`install_k3s.sh`](installation_utils/install_k3s.sh) | K3s without enabling or starting its service. |

```bash
bash deployment/scripts/installation_utils/install_os_tools_and_software.sh
```

To install Docker and the general utilities while skipping K3s and Helm:

```bash
INSTALL_K3S=false \
  bash deployment/scripts/installation_utils/install_os_tools_and_software.sh
```

The following environment variables control the optional components. Version
variables also apply when running the corresponding component script directly.

| Variable | Default | Effect |
| --- | --- | --- |
| `INSTALL_K3S` | `true` | Install K3s and Helm. Accepts `true` or `false`. |
| `HELM_VERSION` | `v4.3.1` | Helm release; the installer accepts Helm 4 versions. |
| `K3S_VERSION` | `v1.37.2+k3s1` | K3s release. |

The installer enables and starts Docker, adds root and the invoking user to the
Docker group, and sets `vm.max_map_count=262144` immediately and in
`/etc/sysctl.conf`. Start a new login session to pick up Docker group membership.

K3s is installed for later cluster setup; the installer does not initialise or
join a cluster. Its service is not enabled or started. K3s creates a `kubectl`
command if one is not already installed.

### Cluster setup and kubectl access

After installing the prerequisites, run
[`setup_kubernetes_cluster.sh`](installation_utils/setup_kubernetes_cluster.sh)
as the user who will run `kubectl`; it invokes `sudo` internally. The script
forwards remaining arguments to the K3s setup command.

Create a K3s server, or join a worker on another host with K3s already installed:

```bash
bash deployment/scripts/installation_utils/setup_kubernetes_cluster.sh k3s server
bash deployment/scripts/installation_utils/setup_kubernetes_cluster.sh k3s agent \
  --server https://SERVER:6443 --token SERVER_TOKEN
```

The K3s server token is stored at `/var/lib/rancher/k3s/server/node-token`.

Control-plane setup copies the admin kubeconfig to `~/.kube/config` with mode
`0600` if that path does not already exist. To configure access to an existing
cluster without running setup again:

```bash
bash deployment/scripts/installation_utils/setup_kubernetes_cluster.sh kubeconfig /etc/rancher/k3s/k3s.yaml
```

An existing `~/.kube/config` is retained and an explicit access command is printed.
If `KUBECONFIG` is already set, it takes precedence over `~/.kube/config`; use the
printed `--kubeconfig` command to select the new configuration. Without a running
cluster and a valid kubeconfig, `kubectl` may try `localhost:8080`.

### Database clients

[`install_db_utils.sh`](installation_utils/install_db_utils.sh) installs the
PostgreSQL client tools:

```bash
bash deployment/scripts/installation_utils/install_db_utils.sh
```

It uses `postgresql-client` on Debian/Ubuntu and the PostgreSQL 12 module and
`postgresql` package on Red Hat.

### OS detection and Docker settings

The installers use [`detect_os.sh`](installation_utils/detect_os.sh), which
reads `/etc/os-release` and rejects unsupported distributions. To check the
detected distribution without installing anything:

```bash
bash deployment/scripts/installation_utils/detect_os.sh
```

[`docker_installation_settings/`](installation_utils/docker_installation_settings/)
contains optional Docker proxy and DNS configuration examples. See its
[README](installation_utils/docker_installation_settings/README.md) for details.
Adapt these settings to the host; the installers do not apply them automatically.

## Maintenance

[`audit_pip_dependency.sh`](maintenance/audit_pip_dependency.sh) exports locked
Python dependencies with `uv` and checks them with `pip-audit`.

### Prerequisites

- Bash, `uv` and `pip-audit` available on `PATH`.
- The checked-in `docs/pyproject.toml` and `docs/uv.lock` files.
- Network access for dependency resolution and vulnerability lookups.

No sudo privileges are required. The script uses temporary requirements files,
removes them on exit and leaves the project lockfiles unchanged.

### Usage

Audit documentation dependencies:

```bash
bash deployment/scripts/maintenance/audit_pip_dependency.sh
```

Show available options:

```bash
bash deployment/scripts/maintenance/audit_pip_dependency.sh --help
```

To audit the documentation followed by NiFi runtime and development dependencies
from `apps/nifi/uv.lock`:

```bash
bash deployment/scripts/maintenance/audit_pip_dependency.sh --include-nifi
```

The script exits with a nonzero status when an export or audit fails, including
when `pip-audit` reports vulnerabilities.
