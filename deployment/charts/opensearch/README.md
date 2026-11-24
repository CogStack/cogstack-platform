# Standalone OpenSearch

This chart installs the upstream OpenSearch StatefulSet as its own Helm release.
The upstream chart supplies the Kubernetes templates. Set overrides under
`opensearch:` in your values file.

## Install

Run from the repository root. The `opensearch-admin` Secret holds the initial
admin password. Use a file containing just the password, with no trailing
newline. The upstream defaults create three pods with persistent storage.
Check the [cluster prerequisites](https://docs.opensearch.org/latest/opensearch/install/helm/#prerequisites).

```bash
helm repo add opensearch https://opensearch-project.github.io/helm-charts/
helm dependency build deployment/charts/opensearch
kubectl create namespace search
kubectl -n search create secret generic opensearch-admin --from-file=password=/path/to/password
helm upgrade --install opensearch deployment/charts/opensearch --namespace search
```

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

The [imported OpenSearch config](../../../apps/opensearch/config/opensearch.yml)
uses the old Compose discovery variables and certificate paths. The default
install uses upstream config and demo certificates. Prepare a Kubernetes config
with the right discovery and TLS settings before using the imported file.

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
