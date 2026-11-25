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
`certs` at your certificate directory. The archive contains the chart dependency
and the shared OpenSearch config.

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
Transport TLS checks the CA and shared node DN. Set `KUBE_NAMESPACE` or
`CLUSTER_DOMAIN` when issuing the certificate if either differs from `search`
or `cluster.local`. For a fresh cluster, initialize the Security index with
your Security plugin configuration and the local `admin.crt` and `admin.key.pem`.
[`securityadmin.sh` instructions](https://docs.opensearch.org/latest/security/configuration/security-admin/)

From inside the cluster, clients can use
`https://opensearch-cluster-master.search.svc:9200`.

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
