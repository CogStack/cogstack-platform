# Standalone OpenSearch Dashboards

Install this release in the same namespace as [OpenSearch](../opensearch/README.md).
Dashboards connects to the OpenSearch Service and stores its saved objects in
OpenSearch.

From the repository root, load the `dashboards-auth` Secret in the namespace set
in `deployment/env/general.env`. The target uses `OPENSEARCH_KIBANA_PASSWORD` from the
environment, `deployment/env/authentication.env`, or the existing Secret, and
prompts if it needs a password. It generates a cookie key on first use and
reuses it on subsequent runs. Load this Secret before the OpenSearch bootstrap
to share the `kibanaserver` password. If OpenSearch is already initialized, use
its current `kibanaserver` password.

```bash
make -C deployment k3s-load-auth-opensearch-dashboards
```

Set `opensearch-dashboards.opensearchAccount.secret: dashboards-auth` in your Helm
values. Set `opensearch_security.cookie.password: ${COOKIE_PASS}` in your
`opensearch_dashboards.yml` to use the cookie key from the Secret. Use
`opensearchDashboards.index: .kibana` in a fresh deployment to match the built-in
`kibana_server` role.

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
