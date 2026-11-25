# Helm charts

Reusable deployment charts for CogStack. Each chart sits directly under this
directory and declares its package name in `Chart.yaml`.
Folder names use component names, such as `medcat-service` and `jupyter-hub`.

## NiFi charts

These charts were migrated from `cogstack_nifi/deploy/kubernetes/charts/`:

| Chart | Purpose |
| --- | --- |
| [`nifi/`](nifi/README.md) | NiFi StatefulSet, Services, TLS settings and persistent storage. |
| [`nginx/`](nginx/README.md) | TLS reverse proxy for the NiFi web Service, with optional Ingress. |

The `nifi/` directory declares `name: nifi` in `Chart.yaml`, so Helm
packages it as `nifi-<version>.tgz`.

Run from the repository root:

```bash
helm lint deployment/charts/nifi deployment/charts/nginx
helm template cogstack-nifi deployment/charts/nifi --namespace cogstack
helm template cogstack-nginx deployment/charts/nginx --namespace cogstack
```

See each chart's README for the ConfigMaps, Secrets and storage needed before
installation. Run `make -C deployment helm-values-<chart>` for NiFi, NGINX,
OpenSearch, or OpenSearch Dashboards to render `values.env.yaml` into
`values.yaml` using `deployment/env/<chart>.env`. NGINX reads `nifi.env` for
the upstream connection and applies `nginx.env` when present. The local
`deployment/env/nifi.env` can link to `apps/nifi/env/nifi.env`. Docker memory
sizes such as `2g` render as `2Gi`.

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
