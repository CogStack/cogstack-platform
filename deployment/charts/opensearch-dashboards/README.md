# Standalone OpenSearch Dashboards

Install this release in the same namespace as [OpenSearch](../opensearch/README.md).
Dashboards connects to the OpenSearch Service and stores its saved objects in
OpenSearch.

For the shared Security policy, set `opensearch-dashboards.opensearchAccount.secret`
to a Secret in the release namespace with keys `username`, `password`, and `cookie`.
Use `kibanaserver`, the same password as `KIBANA_PASSWORD` at bootstrap, and a
random cookie key. Use `opensearchDashboards.index: .kibana` in a fresh deployment
to match the built-in `kibana_server` role.

```bash
helm repo add opensearch https://opensearch-project.github.io/helm-charts/
helm dependency build deployment/charts/opensearch-dashboards
helm upgrade --install opensearch-dashboards deployment/charts/opensearch-dashboards -n search
```

Set overrides under `opensearch-dashboards:` in your values file. Prepare the
[imported Compose config](../../../apps/opensearch-dashboards/config/opensearch.yml)
with the Kubernetes endpoint, credentials, and certificate paths before using it.
Use `--set-file` to load a prepared config.

```bash
helm upgrade --install opensearch-dashboards deployment/charts/opensearch-dashboards -n search \
  --set-file 'opensearch-dashboards.config.opensearch_dashboards\.yml=/path/to/kubernetes/opensearch_dashboards.yml'
```

Mount TLS files from a Secret using `opensearch-dashboards.secretMounts`. See the
[upstream values](https://github.com/opensearch-project/helm-charts/blob/main/charts/opensearch-dashboards/values.yaml).
