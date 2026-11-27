# Standalone OpenSearch

This chart installs the upstream OpenSearch StatefulSet as its own Helm release.
The upstream chart supplies the Kubernetes templates. Set overrides under
`opensearch:` in your values file.

## Install

OpenSearch serves HTTP on the internal `opensearch-cluster-master` Service.
OpenSearch Security requires TLS on its node transport. Generate the shared
node certificate with an existing CA and load it into the release namespace.
Use an absolute `SECURITY_DIR` for a custom certificate directory.
[Cluster prerequisites](https://docs.opensearch.org/latest/opensearch/install/helm/#prerequisites)

```bash
make -C deployment -j1 certs-opensearch-nodes k3s-load-certs-opensearch NODES=opensearch-shared
make -C deployment helm-install-opensearch-stack
```

The stack target prepares the authentication Secrets, then installs OpenSearch
and Dashboards. It uses `KUBE_NAMESPACE` from `deployment/env/general.env`.

To install OpenSearch on its own, prepare the bootstrap Secret before installing.

```bash
make -C deployment k3s-load-auth-opensearch
make -C deployment helm-install-opensearch
```

The loader requires `htpasswd`. Set `OPENSEARCH_KIBANA_PASSWORD` for
`kibanaserver` in the environment or `deployment/env/authentication.env`. It
also accepts the password from a preexisting `dashboards-auth` Secret. Set
`OPENSEARCH_NIFI_PASSWORD`, `OPENSEARCH_PIPELINE_PASSWORD`, or
`OPENSEARCH_ANALYST_PASSWORD` to create `nifi`, `cogstack_pipeline`, or
`cogstack_user`. Set `OPENSEARCH_ADMIN_PASSWORD` to create a password-based
`admin` with the `all_access` role. Use `OPENSEARCH_AUTH_FILE` to select another
credentials file.

OpenSearch uses `opensearch-security-bootstrap` to initialize an empty Security
index. For an existing cluster that uses an admin certificate, create a
password-authenticated administrator in the existing Security index before
switching to HTTP. Use the current `kibanaserver` password when loading the
Dashboards Secret.

Clients in the release namespace can use `http://opensearch-cluster-master:9200`.
External clients use the NGINX `/opensearch/` route over HTTPS.

## Replicas

Set `OPENSEARCH_K3S_REPLICA_COUNT` in `deployment/env/opensearch.env`
and run `make -C deployment helm-values-opensearch` before installing or
scaling up with Helm. The default is one replica. Required pod anti-affinity
places each replica on a separate Kubernetes node, so two replicas require
two schedulable nodes.

To exclude nodes, set `OPENSEARCH_K3S_BLACKLIST` in the same env file to
comma-separated names from `kubectl get nodes`, such as `worker-1,worker-2`.
An empty list allows all otherwise eligible nodes. Rerender the values and
upgrade the release after editing the list. A replica with a PVC tied to an
excluded node can stay Pending.

Both members of a two-node cluster are needed for quorum. Use three replicas
on three nodes to tolerate one node failure.
[OpenSearch quorum rules](https://docs.opensearch.org/3.9/tuning-your-cluster/discovery-cluster-formation/voting-quorums/)

## Storage

The StatefulSet creates one PVC per replica and mounts it at
`/usr/share/opensearch/data`. Set `OPENSEARCH_K3S_VOLUME_SIZE` in
`apps/opensearch/env/opensearch.env` to a Kubernetes quantity such as `100Gi`.
The default is `8Gi`. Set `OPENSEARCH_K3S_STORAGE_CLASS` to a named StorageClass
or leave it empty to use the cluster default.

Render the values and inspect the claim template before installing.

```bash
make -C deployment helm-values-opensearch
helm template opensearch deployment/charts/opensearch -n cogstack \
  --show-only charts/opensearch/templates/statefulset.yaml
```

After installing, list claims with `kubectl -n cogstack get pvc`. For direct
Helm installs, set `opensearch.persistence.size` and
`opensearch.persistence.storageClass` in your values file.

Kubernetes treats the StatefulSet claim template as immutable. To grow an
existing volume, update its PVC's storage request if the StorageClass supports
expansion. [PVC expansion](https://kubernetes.io/docs/concepts/storage/persistent-volumes/#expanding-persistent-volumes-claims)

## Configuration

`helm-install-opensearch` loads the bundled configuration with `--set-file` and
applies `OPENSEARCH_LOG_LEVEL` from `deployment/env/opensearch.env`. The chart
sets `plugins.security.ssl.http.enabled=false` and enables Security bootstrap
from the mounted policy through the OpenSearch container's settings environment.

### Custom values

For direct Helm installs, build the dependency and load a config file. The
release also requires the `opensearch-security-bootstrap` and
`opensearch-node-tls` Secrets in the same namespace.

```bash
chart=deployment/charts/opensearch
helm repo add opensearch https://opensearch-project.github.io/helm-charts/
helm dependency build "$chart"
helm upgrade --install opensearch "$chart" -n cogstack \
  --set-file "opensearch.config.opensearch\.yml=$chart/config/opensearch.yml"
```

For a packaged chart, set `chart=./opensearch` after extracting it. The archive
includes the chart dependency, OpenSearch configuration, and Security policy.
