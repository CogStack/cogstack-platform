# CogStack HAPI FHIR Helm chart

A [HAPI FHIR](https://hapifhir.io/) JPA server (FHIR R4) with PostgreSQL as the
resource store and a single-node Elasticsearch as its full-text index, which is
what answers `_text` and `_content` searches. Every other search stays in
PostgreSQL, so a search straight after a write still sees it.

| Workload | Image | Service | Storage |
| --- | --- | --- | --- |
| `hapi-fhir` | `hapiproject/hapi:v8.12.0-2` | `hapi-fhir:8080` | none |
| `hapi-fhir-db` | `postgres:16-alpine` | `hapi-fhir-db:5432` | 10Gi PVC |
| `hapi-fhir-es` | `docker.elastic.co/elasticsearch/elasticsearch:8.19.19` | `hapi-fhir-es:9200` | 10Gi PVC |

## No templating

The files in `templates/` are plain Kubernetes YAML. They contain no Helm
template expressions, and the chart has no values: `helm template` prints them
as they are written. Helm packages, versions, installs and removes the chart,
and nothing else.

This has three consequences.

- **Fixed names.** Resource names do not include the release name, so install
  one release per namespace.
- **No `--set`.** To change an image, a size or a setting, edit the manifests
  (or post-process them with `helm template | kustomize`).
- **No automatic restart on a configuration change.** HAPI reads the
  `hapi-fhir-config` ConfigMap only at startup. After an upgrade that changes
  it, run `kubectl rollout restart deployment/hapi-fhir`.

## Install

The chart does not contain the database password. Create the `hapi-fhir-db`
Secret first, in the namespace you install into. Keep it across upgrades:
PostgreSQL sets the password only when it first initialises its volume.

```bash
kubectl create namespace cogstack
kubectl -n cogstack create secret generic hapi-fhir-db \
  --from-literal=POSTGRES_PASSWORD="$(openssl rand -hex 24)"
helm upgrade --install hapi-fhir deployment/charts/hapi-fhir -n cogstack \
  --wait --timeout 15m
```

HAPI waits for PostgreSQL and Elasticsearch, then migrates its schema. The
first start takes a few minutes.

## Access

The chart creates only ClusterIP Services. It has no Ingress or HTTPRoute,
because a hostname cannot be set without templating. PostgreSQL and
Elasticsearch are meant to stay inside the cluster; Elasticsearch runs without
authentication.

```bash
kubectl -n cogstack port-forward svc/hapi-fhir 8080:8080
curl http://localhost:8080/fhir/metadata
curl 'http://localhost:8080/fhir/Patient?_text=x&_summary=count'
```

The second request answers `400` (`HAPI-1192`) if HAPI is not using
Elasticsearch.

To publish the server, route your own Ingress or Gateway API HTTPRoute to the
`hapi-fhir` Service on port `8080`. HAPI builds its links from the
`X-Forwarded-*` headers the proxy sends.

If resources were stored before Elasticsearch was attached, index them once:

```bash
curl -X POST 'http://localhost:8080/fhir/$reindex' \
  -H 'Content-Type: application/fhir+json' \
  -d '{"resourceType":"Parameters"}'
```

## Sizing

Elasticsearch runs with a 512 MB heap and a 1200Mi memory limit, and uses
`node.store.allow_mmap=false` so the nodes need no `vm.max_map_count` change.
PostgreSQL is tuned for about 2 GB of memory. These suit a small shared
cluster; edit the manifests for anything larger.

## Remove

```bash
helm uninstall hapi-fhir -n cogstack
```

This deletes the PersistentVolumeClaims, and with them the data. The
`hapi-fhir-db` Secret is yours to delete.
