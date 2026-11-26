# Helm charts

Reusable deployment charts for CogStack. Each chart sits directly under this
directory and declares its package name in `Chart.yaml`.
Folder names use component names, such as `medcat-service` and `jupyter-hub`.

## Kubernetes HTTPS entry point

Deploy the four standalone charts in the same namespace. NGINX serves HTTPS
for the stack and forwards requests to the application Services over HTTP.

- **NiFi (`nifi/`)** runs Apache NiFi as a StatefulSet with persistent storage
  for flow configuration and repositories. A NetworkPolicy restricts its
  internal HTTP port `8080` to NGINX pods. Users reach the UI at `/nifi/` and the
  API at `/nifi-api/`. [NiFi chart](nifi/README.md)
- **NGINX (`nginx/`)** exposes a `LoadBalancer` Service on port `443` and
  terminates TLS with the `nginx-tls` Secret. It handles NiFi Basic Auth using
  credentials from `nifi-auth`. [NGINX chart](nginx/README.md)
- **OpenSearch (`opensearch/`)** runs a StatefulSet with persistent storage.
  OpenSearch Security controls access to the HTTP REST API on port `9200`, which
  NGINX exposes at `/opensearch/`. The `opensearch-node-tls` Secret secures node
  transport on port `9300`. [OpenSearch chart](opensearch/README.md)
- **OpenSearch Dashboards (`opensearch-dashboards/`)** serves the UI over HTTP
  on port `5601` behind NGINX at `/dashboards/`. It connects to OpenSearch using
  the `dashboards-auth` service account Secret. Users sign in with their
  OpenSearch accounts. [OpenSearch Dashboards chart](opensearch-dashboards/README.md)

### Install the standalone charts

For a new deployment, set `NGINX_TLS_NAMES` to the hostname or IP clients will
use. Supply your deployment credentials. The OpenSearch loader uses `htpasswd`
(`apache2-utils` on Debian/Ubuntu or `httpd-tools` on RHEL). Follow the host
prerequisites, then run these commands from the repository root.
[On-premises deployment guide](../README.md)

```bash
make -C deployment setup-k3s-namespace
make -C deployment certs-k3s
make -C deployment helm-install-all
```

Existing deployments must reload `nifi-auth` for NGINX before upgrading.
OpenSearch upgrades also require the bootstrap Secret and preparation of
administrative access when using an admin certificate. [OpenSearch upgrade details](opensearch/README.md#install)

## Chart development

```bash
helm lint deployment/charts/nifi deployment/charts/nginx
helm template cogstack-nifi deployment/charts/nifi --namespace cogstack
helm template cogstack-nginx deployment/charts/nginx --namespace cogstack
```

See each chart's README for the ConfigMaps, Secrets and storage needed before
installation. Run `make -C deployment helm-values-<chart>` for NiFi, NGINX,
OpenSearch, or OpenSearch Dashboards to render `values.env.yaml` into
`values.yaml` using `deployment/env/<chart>.env`. NGINX reads `nifi.env` for
its listener port and applies `nginx.env` when present. Docker memory sizes such
as `2g` render as `2Gi`.

## Validation and releases

The shared chart workflow discovers `deployment/charts/*/Chart.yaml` for
validation and packaging. Release-please registers each chart by its directory
and uses its configured component for release tags, such as
`helm-charts/nifi-v0.1.0`. The migrated charts start at `0.1.0` for their
first platform release.

The NiFi charts include `ci/ci-values.yaml` with zero replicas so chart-testing
can validate Kubernetes resource installation without deployment-owned
ConfigMaps and Secrets. Application startup and TLS checks require a separate
runtime test with those inputs supplied.

To package locally, keep generated archives outside the source tree:

```bash
helm package deployment/charts/nifi --destination /tmp
helm package deployment/charts/nginx --destination /tmp
```
