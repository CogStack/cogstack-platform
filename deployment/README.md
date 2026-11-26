# CogStack deployment

Run the Makefile commands below from the `deployment/` directory. [Deployment Makefile](Makefile)

## On-premises setup

> ⚠️ **Required for a fresh deployment.** Set up K3s and generate or provide the
> NGINX HTTPS and OpenSearch transport certificates before preparing the charts.

Use a Debian, Ubuntu, or RHEL server with a full repository checkout, systemd,
network access, Bash, GNU Make, and `sudo`. With K3s ServiceLB, add `traefik`
to the `disable` list in `/etc/rancher/k3s/config.yaml` on each server before
setup to free TCP port `443` for NGINX. Run the following on the first server.

```bash
export KUBECONFIG="$HOME/.kube/config"
make setup-all
```

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

Set the store passwords in `env/certificates.env` and use the hostname or IP
clients will use for NGINX.

```bash
NGINX_TLS_NAMES=cogstack.example.org make certs-k3s
```

This generates the CA, NGINX HTTPS certificate, and OpenSearch transport
certificate. Reuse an existing bundle from `SECURITY_DIR` when available. The
default directory is `deployment/security`. [Certificate targets](scripts/README.md#certificates)

## Environment settings

| File | Settings used by the deployment |
| --- | --- |
| `env/general.env` | `KUBE_NAMESPACE` (default `cogstack`) and `CLUSTER_DOMAIN`. |
| `env/certificates.env` | `SECURITY_DIR`, `NGINX_TLS_NAMES`, and certificate store passwords. |
| `env/authentication.env` | NiFi login and OpenSearch account passwords. |
| `env/nifi.env` | `NIFI_UID`, `NIFI_GID`, `NIFI_DOCKER_*` resources, `NIFI_K3S_WHITELIST`, and `NIFI_INTERNAL_PORT_NGINX`. |
| `env/nginx.env` (optional) | `NGINX_DOCKER_*` resource overrides and `NGINX_NIFI_SERVER_NAME`. |
| `env/opensearch.env` | `OPENSEARCH_K3S_REPLICA_COUNT`, `OPENSEARCH_K3S_BLACKLIST`, `OPENSEARCH_DOCKER_*` resources, and `OPENSEARCH_LOG_LEVEL`. |
| `env/opensearch-dashboards.env` | `OPENSEARCH_DASHBOARDS_DOCKER_*` resources. |

Put your passwords in a private copy of `env/authentication.env` and export its
absolute path as `NIFI_AUTH_FILE` and `OPENSEARCH_AUTH_FILE`. Set
`NIFI_SINGLE_USER_CREDENTIALS_USERNAME` and `NIFI_SINGLE_USER_CREDENTIALS_PASSWORD`
for NiFi, `OPENSEARCH_KIBANA_PASSWORD` for the Dashboards service account, and
`OPENSEARCH_ANALYST_PASSWORD` to sign in to Dashboards as `cogstack_user`.
Install `htpasswd` for OpenSearch (`apache2-utils` on Debian or Ubuntu,
`httpd-tools` on RHEL).

A fresh checkout needs an `apps/nifi/env/nifi.env` file for the `env/nifi.env`
symlink. [NiFi environment defaults](charts/README.md#nifi-environment)

## Prepare Kubernetes resources

After setting the environment and certificates, prepare the full stack before
running the install commands individually.

```bash
make k3s-prepare-all
```

This renders Helm values (`helm-values-all`), loads TLS Secrets
(`k3s-load-certs-all`), loads runtime ConfigMaps (`k3s-load-env-all`), and loads
authentication Secrets (`k3s-load-auth-all`). `make helm-install-all` includes
this preparation and installs all four services.

## Install the applications

With the namespace prepared, choose a stack or install the charts individually.

| Makefile command | What it installs or upgrades |
| --- | --- |
| `make helm-install-nifi-stack` | NiFi, then NGINX for the HTTPS UI and API. |
| `make helm-install-opensearch-stack BOOTSTRAP_OPENSEARCH_SECURITY=0` | OpenSearch, then Dashboards using the prepared authentication Secrets. |
| `make helm-install-nifi` | The NiFi StatefulSet. Use NGINX for HTTPS access. |
| `make helm-install-nginx` | The HTTPS gateway for the backends you deploy. |
| `make helm-install-opensearch` | The OpenSearch cluster and its REST API. |
| `make helm-install-opensearch-dashboards` | Dashboards. Install OpenSearch first. |

`helm-install-opensearch-stack` defaults to `BOOTSTRAP_OPENSEARCH_SECURITY=1`,
which loads its authentication Secrets. Use `0` after `k3s-prepare-all` to reuse
those Secrets. Run `make help` for the individual preparation and install targets.
For single-chart overrides, pass `HELM_VALUES=/absolute/path.yaml` to its
install command. [Chart configuration and routes](charts/README.md#kubernetes-https-entry-point)

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
