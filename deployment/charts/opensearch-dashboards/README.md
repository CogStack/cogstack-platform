# Standalone OpenSearch Dashboards

Deploy Dashboards in the same namespace as OpenSearch and NGINX. Dashboards
serves HTTP on its ClusterIP Service and connects to OpenSearch over HTTP.
Clients use `/dashboards/` over HTTPS through NGINX. The session cookie is Secure.

From the repository root, load the `dashboards-auth` Secret in the namespace set
in `deployment/env/general.env`. The target uses `OPENSEARCH_KIBANA_PASSWORD` from the
environment, `deployment/env/authentication.env`, or the existing Secret, and
prompts if it needs a password. It generates a cookie key on first use and
reuses it on subsequent runs. Load this Secret before the OpenSearch bootstrap
to share the `kibanaserver` password. If OpenSearch is already initialized, use
its current `kibanaserver` password.

```bash
make -C deployment k3s-load-auth-opensearch-dashboards
make -C deployment helm-install-opensearch-dashboards
```

The default values use `dashboards-auth` and `.kibana`, which matches the
built-in `kibana_server` role. Keep any existing saved-object index override
when upgrading. If you supply a custom `opensearch_dashboards.yml`, set
`server.ssl.enabled: false`, `server.basePath: /dashboards`,
`server.rewriteBasePath: true` and `opensearch_security.cookie.secure: true`.
Use `opensearch_security.cookie.password: ${COOKIE_PASS}` for the cookie key
from the Secret.

```bash
helm repo add opensearch https://opensearch-project.github.io/helm-charts/
helm dependency build deployment/charts/opensearch-dashboards
helm upgrade --install opensearch-dashboards deployment/charts/opensearch-dashboards -n cogstack
```

Set overrides under `opensearch-dashboards:` in your values file. Use
`--set-file` to supply a complete Kubernetes configuration.

```bash
helm upgrade --install opensearch-dashboards deployment/charts/opensearch-dashboards -n cogstack \
  --set-file 'opensearch-dashboards.config.opensearch_dashboards\.yml=/path/to/kubernetes/opensearch_dashboards.yml'
```

Dashboards inherits its Kubernetes templates from the upstream chart.
[Upstream values](https://github.com/opensearch-project/helm-charts/blob/main/charts/opensearch-dashboards/values.yaml)
