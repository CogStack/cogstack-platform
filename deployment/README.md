# CogStack deployment

Run the Makefile commands below from the `deployment/` directory. [Deployment Makefile](Makefile)

## Quickstart after setup

After `make setup-all` succeeds, set `NGINX_TLS_NAMES` in `env/certificates.env`
to the hostname or IP clients will use for NGINX. Set the certificate store
passwords, provide deployment credentials, and copy `../apps/nifi/env/nifi.env.example`
to `../apps/nifi/env/nifi.env` if it’s missing. [Environment settings](#environment-settings)

```bash
make certs-all
make k3s-prepare-all
```

`certs-all` generates the certificate bundle. `k3s-prepare-all` renders Helm
values and loads the TLS Secrets, runtime ConfigMaps, and authentication Secrets.

To deploy all four services, run `make certs-all` followed by
`make helm-install-all`, which runs preparation automatically.
[Install options](#install-the-applications)

## On-premises setup

Use a Debian, Ubuntu, or RHEL server with a full repository checkout, systemd,
network access, Bash, GNU Make, and `sudo`.

`setup-all` runs `setup-install-pre-requisites`, `setup-k3s-cluster-init`,
`setup-k3s-namespace`, and `setup-verify` in order. It installs the host tools,
Docker, K3s, and Helm, then creates the namespace from `env/general.env`.

- For an existing cluster, point `KUBECONFIG` at it and run
  `make setup-k3s-namespace`. The cluster needs NetworkPolicy enforcement and a
  StorageClass for NiFi and OpenSearch. [Kubeconfig setup](scripts/README.md#kubectl-access)
- If Docker verification reports a group permission error, sign in again, set
  `KUBECONFIG`, and run `make setup-verify`. For multiple servers, use the
  [SSH cluster setup guide](scripts/README.md#set-up-a-cluster-over-ssh).

### Generate certificates

Use `make certs-k3s` to generate the CA, NGINX HTTPS certificate, and OpenSearch
transport certificate for K3s. If you already have a bundle, set
`SECURITY_DIR` to the directory containing `certificates/` and start with
`make k3s-prepare-all`. The default directory is `deployment/security`.
[Certificate targets](scripts/README.md#certificates)

## Environment settings

| File | Settings used by the deployment |
| --- | --- |
| `env/general.env` | `KUBE_NAMESPACE` (default `cogstack`) and `CLUSTER_DOMAIN`. |
| `env/certificates.env` | `SECURITY_DIR`, `NGINX_TLS_NAMES`, and certificate store passwords. |
| `env/authentication.env` | NiFi login and OpenSearch account passwords. |
| `env/nifi.env` | `NIFI_UID`, `NIFI_GID`, `NIFI_DOCKER_*` resources, `NIFI_INTERNAL_PORT_NGINX`, `NIFI_K3S_WHITELIST`, `NIFI_K3S_STORAGE_CLASS`, and `NIFI_K3S_*_VOLUME_SIZE`. [NiFi storage settings](charts/nifi/README.md#persistent-configuration-and-data) |
| `env/nginx.env` (optional) | `NGINX_DOCKER_*` resource overrides and `NGINX_NIFI_SERVER_NAME`. |
| `env/opensearch.env` | `OPENSEARCH_K3S_REPLICA_COUNT`, `OPENSEARCH_K3S_BLACKLIST`, `OPENSEARCH_K3S_VOLUME_SIZE`, `OPENSEARCH_K3S_STORAGE_CLASS`, `OPENSEARCH_DOCKER_*` resources, and `OPENSEARCH_LOG_LEVEL`. |
| `env/opensearch-dashboards.env` | `OPENSEARCH_DASHBOARDS_DOCKER_*` resources. |

`k3s-prepare-all` reads login credentials from `env/authentication.env` by
default. To use a private copy, export its absolute path as `NIFI_AUTH_FILE`
and `OPENSEARCH_AUTH_FILE`. Set
`NIFI_SINGLE_USER_CREDENTIALS_USERNAME` and `NIFI_SINGLE_USER_CREDENTIALS_PASSWORD`
for NiFi, `OPENSEARCH_KIBANA_PASSWORD` for the Dashboards service account, and
`OPENSEARCH_ANALYST_PASSWORD` to sign in to Dashboards as `cogstack_user`.
The NiFi loader prompts if its password is empty or still uses the checked-in
Compose sample.

## Install the applications

After `make k3s-prepare-all`, choose a stack or install the charts individually.

| Makefile command | What it installs or upgrades |
| --- | --- |
| `make helm-install-nifi-stack` | NiFi, then NGINX for the HTTPS UI and API. |
| `make helm-install-opensearch-stack` | OpenSearch, then Dashboards using the prepared authentication Secrets. |
| `make helm-install-nifi` | The NiFi StatefulSet. Use NGINX for HTTPS access. |
| `make helm-install-nginx` | The HTTPS gateway for the backends you deploy. |
| `make helm-install-opensearch` | The OpenSearch cluster and its REST API. |
| `make helm-install-opensearch-dashboards` | Dashboards. Install OpenSearch first. |

### Standalone JupyterHub

Run `make helm-install-jupyter-hub` with the namespace from `env/general.env`
in place. Use `make setup-k3s-namespace` to create the namespace if needed.
[JupyterHub chart values](charts/jupyter-hub/values.yaml)

## Verify and access the applications

Replace `cogstack` with your `KUBE_NAMESPACE` if you changed it.

```bash
helm list -n cogstack
kubectl -n cogstack get pods,pvc,svc
```

Check that your selected releases are deployed, their pods are ready, and their
PVCs are bound. Point your DNS name at the external address of `cogstack-nginx`
and trust `deployment/security/certificates/root/root-ca.pem` on client machines.
Use HTTPS at `/nifi/`, `/opensearch/`, or `/dashboards/`.
