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

The installers recognise Debian, Ubuntu, Red Hat Enterprise Linux and CentOS.
Package and repository availability depends on the distribution release. They
require Bash, `sudo`, internet access to package repositories and a host using
systemd. They invoke `sudo` internally, including when run as root.

Both installers update and upgrade system packages. The Docker installer also
changes package repositories, Docker group membership and system settings; its
Red Hat/CentOS branch removes existing Docker packages, Podman and Buildah.
Review the script before running it on an existing host.

### Docker and platform tools

[`install_docker_and_utils.sh`](installation_utils/install_docker_and_utils.sh)
installs Docker Engine, Buildx, Compose, Azure CLI, Python utilities, filesystem
tools, monitoring tools and build dependencies. By default it also installs
Kubernetes tools, Helm and K3s.

```bash
bash deployment/scripts/installation_utils/install_docker_and_utils.sh
```

To install Docker and the general utilities while skipping Kubernetes, Helm and
K3s:

```bash
INSTALL_KUBERNETES=false INSTALL_K3S=false \
  bash deployment/scripts/installation_utils/install_docker_and_utils.sh
```

The following environment variables control the optional components. Versions
shown are the defaults configured in the script.

| Variable | Default | Effect |
| --- | --- | --- |
| `INSTALL_KUBERNETES` | `true` | Install `kubeadm`, `kubelet`, `kubectl` and Helm. Accepts `true` or `false`. |
| `INSTALL_K3S` | Value of `INSTALL_KUBERNETES` | Install K3s independently of the Kubernetes tools. Accepts `true` or `false`. |
| `KUBERNETES_MINOR_VERSION` | `v1.37` | Kubernetes package repository minor release. |
| `HELM_VERSION` | `v4.3.1` | Helm release; the installer accepts Helm 4 versions. |
| `K3S_VERSION` | `v1.37.2+k3s1` | K3s release. |

To install the Kubernetes tools and Helm while skipping K3s:

```bash
INSTALL_K3S=false \
  bash deployment/scripts/installation_utils/install_docker_and_utils.sh
```

The installer enables and starts Docker, adds root and the invoking user to the
Docker group, and sets `vm.max_map_count=262144` immediately and in
`/etc/sysctl.conf`. Start a new login session to pick up Docker group membership.

Kubernetes packages are installed for later cluster setup; the installer does
not initialise or join a cluster. It enables the kubelet service and holds the
Kubernetes packages on Debian/Ubuntu. K3s installation skips enabling and starting
its service, and preserves the standalone `kubectl` command.

### Database clients

[`install_db_utils.sh`](installation_utils/install_db_utils.sh) installs the
PostgreSQL client tools:

```bash
bash deployment/scripts/installation_utils/install_db_utils.sh
```

It uses `postgresql-client` on Debian/Ubuntu and the PostgreSQL 12 module and
`postgresql` package on Red Hat/CentOS.

### OS detection and Docker settings

Both installers use [`detect_os.sh`](installation_utils/detect_os.sh), which
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

The script also exposes `--include-nifi`, which audits the documentation first
and then exports all dependency groups from a repository-root Python project.
This checkout has no root `pyproject.toml` or `uv.lock`, so that option requires
updating the script to the intended NiFi project location before use.

The script exits with a nonzero status when an export or audit fails, including
when `pip-audit` reports vulnerabilities.
