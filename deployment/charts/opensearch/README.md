# Standalone OpenSearch

This chart installs the upstream OpenSearch StatefulSet as its own Helm release.
The upstream chart supplies the Kubernetes templates. Set overrides under
`opensearch:` in your values file.

## Install

The chart defaults to a shared node certificate. From the repository root, build
the chart dependency and generate the node and admin client certificates with
an existing CA. The generator prompts for `OS_CERTIFICATE_PASSWORD` when unset.
Use an absolute `SECURITY_DIR` for a custom output location.
[Cluster prerequisites](https://docs.opensearch.org/latest/opensearch/install/helm/#prerequisites)

```bash
chart=deployment/charts/opensearch
helm repo add opensearch https://opensearch-project.github.io/helm-charts/
helm dependency build "$chart"
make -C deployment certs-opensearch
certs="${SECURITY_DIR:-deployment/security}/certificates/opensearch"
```

For a packaged chart, set `chart=./opensearch` after extracting it and point
`certs` at your certificate directory. The archive contains the chart dependency,
the shared OpenSearch config, and the Security policy.

```bash
kubectl create namespace search
kubectl -n search create secret generic opensearch-node-tls \
  --from-file=node.crt="$certs/opensearch-shared.crt" \
  --from-file=node.key="$certs/opensearch-shared.key" \
  --from-file=ca.crt="$certs/elastic-stack-ca.crt.pem"
helm upgrade --install opensearch "$chart" -n search \
  --set-file "opensearch.config.opensearch\.yml=$chart/config/opensearch.yml"
```

Helm loads the bundled [`opensearch.yml`](config/opensearch.yml) through `--set-file`.
`make -C deployment helm-install-opensearch` applies `OPENSEARCH_LOG_LEVEL`
from `deployment/env/opensearch.env` before invoking Helm. To apply all three
runtime ConfigMaps together, run `make -C deployment k3s-load-env-all`.

Transport TLS checks the CA and shared node DN. Set `KUBE_NAMESPACE` or
`CLUSTER_DOMAIN` when issuing the certificate if either differs from `search`
or `cluster.local`.

### Authentication

For K3s, initialize Security after OpenSearch starts. The Make target uses
`KUBE_NAMESPACE` from `deployment/env/general.env`.

```bash
make -C deployment k3s-load-auth-opensearch
```

Set `OPENSEARCH_KIBANA_PASSWORD` in the environment or in `deployment/env/authentication.env`.
Use `OPENSEARCH_AUTH_FILE` to select a different file. If no password is supplied,
the target uses `dashboards-auth` if present or prompts in a terminal. The same
file or environment can supply the optional user passwords below. On an
initialized cluster the target reports that Security is already initialized.

For direct Helm installs, run the bootstrap script with the following settings.
Export `OPENSEARCH_KIBANA_PASSWORD` for `kibanaserver`. Set
`OPENSEARCH_NIFI_PASSWORD`, `OPENSEARCH_PIPELINE_PASSWORD`, or
`OPENSEARCH_ANALYST_PASSWORD` to create `nifi`,
`cogstack_pipeline`, or `cogstack_user`, respectively. Export the absolute
`SECURITY_DIR` for a packaged chart or custom certificate location. After the
OpenSearch cluster forms, initialize Security once before starting Dashboards.

```bash
bash "$chart/security/bootstrap.sh" kubectl -n search exec -i opensearch-cluster-master-0 --
```

From inside the cluster, clients can use
`https://opensearch-cluster-master.search.svc:9200`.

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

The StatefulSet creates one 8 GiB PVC per pod and mounts it at
`/usr/share/opensearch/data`. Set `opensearch.persistence.size` and
`opensearch.persistence.storageClass` before installing. The first command
shows the claim template. The second lists claims after installation.

```bash
helm template opensearch deployment/charts/opensearch -n search \
  --show-only charts/opensearch/templates/statefulset.yaml
kubectl -n search get pvc
```

## Configuration and TLS

The chart links to the source at `apps/opensearch/config/opensearch.yml`.
In Docker, mount the source at `/usr/share/opensearch/config/opensearch.yml`.
Mount the shared certificate, key, and public CA as `node.crt`, `node.key`,
and `ca.crt` under `/usr/share/opensearch/config/tls`.

### Custom values

Pass a prepared file to Helm. The chart creates a ConfigMap and uses it to
populate the file mounted at `/usr/share/opensearch/config/opensearch.yml`.

```bash
helm upgrade --install opensearch deployment/charts/opensearch -n search \
  --set-file 'opensearch.config.opensearch\.yml=/path/to/kubernetes/opensearch.yml'
```

Put TLS keys and certificates in a Kubernetes Secret and mount it using
`opensearch.secretMounts`. Match the PEM paths in the config to the mount.
See the [upstream chart settings](https://github.com/opensearch-project/helm-charts/blob/main/charts/opensearch/README.md).

Install Dashboards separately using the
[standalone Dashboards chart](../opensearch-dashboards/README.md).
