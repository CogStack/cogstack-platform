# Deployment scripts

Run commands from the repository root. Installation and cluster setup require Make,
Bash, `sudo`, systemd and network access. They invoke `sudo` internally. Run setup
as the user who will use `kubectl`.

## Certificates

All five generators use OpenSSL and accept `--days DAYS`. The default validity
is 1,460 days for the root CA and OpenSearch certificates and 397 days for
NiFi and NGINX. The root CA, NiFi and OpenSearch node generators also use
Java's `keytool`. `SECURITY_DIR` defaults to `deployment/security/`.

The generators prompt for missing passwords with hidden input in a terminal.
Export the required variables before running from CI or with redirected input.

To use [sample store passwords](../env/certificates.env) for local development,
load them before running the root CA and NiFi generators.

```bash
set -a
source deployment/env/certificates.env
set +a
```

The root CA generator uses `ROOT_CERTIFICATE_KEYSTORE_PASSWORD`.

```bash
./deployment/scripts/security/create_root_ca_cert.sh
```

### NiFi

Use the `KEYSTORE_PASSWORD` and `TRUSTSTORE_PASSWORD` that NiFi will use.
The legacy `NIFI_KEYSTORE_PASSWORD` and `NIFI_TRUSTSTORE_PASSWORD` names are
also accepted.

Choose the command for your deployment. The default NiFi certificate covers
`nifi`, `localhost`, `cogstack-nifi`, `cogstack-nifi-headless`, and `127.0.0.1`.

```bash
./deployment/scripts/security/create_nifi_certs.sh
```

When NGINX and NiFi run on separate Docker hosts, add the DNS name NGINX will
verify. `NIFI_HEALTHCHECK_HOST` also adds a name when supplied.

```bash
NIFI_UPSTREAM_TLS_NAME=nifi.internal.example ./deployment/scripts/security/create_nifi_certs.sh
```

For Kubernetes, set `KUBE_NAMESPACE` to include the web Service's full name.
For example, `cogstack` adds `cogstack-nifi.cogstack.svc.cluster.local`.
Set `CLUSTER_DOMAIN` if your cluster uses a domain other than `cluster.local`.

```bash
KUBE_NAMESPACE=cogstack ./deployment/scripts/security/create_nifi_certs.sh
```

Each invocation writes `nifi.key`, `nifi.csr`, `nifi.pem`, `nifi.crt` (DER),
`nifi.p12`, `nifi-keystore.jks`, and `nifi-truststore.jks` under
`$SECURITY_DIR/certificates/nifi/`.

### NGINX

Use the existing root CA to issue the browser-facing certificate. Set
`NGINX_TLS_NAMES` to a comma-separated list of DNS names or IP addresses,
including wildcard DNS names. The supplied list replaces the defaults of
`localhost` and `127.0.0.1`.

```bash
NGINX_TLS_NAMES='*.cogstack.internal,192.0.2.10' ./deployment/scripts/security/create_nginx_certs.sh
```

The generator writes `tls.crt` and `tls.key` under
`$SECURITY_DIR/certificates/nginx/` and keeps the key at mode `0600`.
It runs without a store password or `keytool`.

### OpenSearch

Use `OS_CERTIFICATE_PASSWORD` for the Java and PKCS#12 stores. Pass the node
hostnames when generating the node certificates. Generate the Dashboards and
admin certificates with the second command.

```bash
./deployment/scripts/security/create_opensearch_node_cert.sh --days 365 opensearch-1 opensearch-2
./deployment/scripts/security/create_opensearch_client_admin_certs.sh --days 365
```

Add comma-separated DNS aliases using `OPENSEARCH_NODE_DNS_NAMES` or
`OPENSEARCH_DASHBOARDS_DNS_NAMES` when clients verify other names, such as
a Kubernetes Service FQDN. Outputs are under
`$SECURITY_DIR/certificates/opensearch/`, with each node's hostname as its file
prefix. Use the issued node and admin subjects in the corresponding OpenSearch
DN settings.

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

## Set up a cluster over SSH

From your workstation, run once with the first server followed by the other servers:

```bash
make -C deployment setup-k3s-cluster-remote \
  NODES="admin@10.0.0.11 admin@10.0.0.12 admin@10.0.0.13"
```

Requires SSH access (key or password), passwordless sudo, Bash and tar on each
machine. Password authentication requires a terminal and may prompt on each
connection. Use unique
hostnames and addresses reachable between nodes. The script installs prerequisites,
initializes the first server, joins the others and verifies Docker and K3s as the
SSH user. Existing members are retained; nodes from another cluster are rejected.
Use one server initially, or three or more servers (an odd total) for HA.

## Join servers manually

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
