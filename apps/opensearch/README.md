# OpenSearch and Dashboards in Docker

From the repository root, run the commands for any missing TLS files.

```bash
make -C deployment certs-root
make -C deployment certs-opensearch
OPENSEARCH_DASHBOARDS_DNS_NAMES=localhost \
  ./deployment/scripts/security/create_opensearch_client_admin_certs.sh --dashboards-only
```

Set an absolute `SECURITY_DIR` to use a different certificate bundle. Each
container runs as UID 1000 and needs read access to its own private key. The
Dashboards certificate must cover the browser hostname.

Export `KIBANA_PASSWORD` from your deployment secrets for the `kibanaserver`
account. Set `OS_NIFI_PASSWORD`, `OS_PIPELINE_PASSWORD`, or `OS_ANALYST_PASSWORD`
to create `nifi`, `cogstack_pipeline`, or `cogstack_user`, respectively.
Run from the repository root on a fresh deployment.

```bash
docker compose -f apps/opensearch/docker/docker-compose.yml up -d
bash apps/opensearch/security/bootstrap.sh \
  docker compose -f apps/opensearch/docker/docker-compose.yml exec -T opensearch
docker compose -f apps/opensearch-dashboards/docker/docker-compose.yml up -d
```

The bootstrap hashes the supplied passwords and applies the shared policy in
[`security/`](security/). Apply changes to existing clusters through the
[Security REST API](https://docs.opensearch.org/latest/security/api/roles/).
Dashboards listens at `https://localhost:5601`.

Compose uses `.kibana` for saved objects to match the bundled Security role.
Set `OPENSEARCHDASHBOARDS_INDEX` when your Security configuration uses another index.

For dev, run this from each app's `docker/` directory, starting with OpenSearch.
Use `opensearch-dashboards.env` for Dashboards.

```bash
docker compose --env-file ../env/opensearch.env \
  -f docker-compose.base.yml -f docker-compose.dev.yml up -d
```

Dev uses the bundled Security users and a separate network. The corresponding
`docker-compose.prod.yml` overlay joins an existing `cogstack-net`. OpenSearch
stores indexes and Security state in `opensearch_data` or `opensearch-dev_data`,
which survive `docker compose down`.
