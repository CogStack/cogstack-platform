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

Start OpenSearch with `docker compose up -d` in `apps/opensearch/docker`.
Initialize the Security index with your users and the admin client certificate
on the first start. Export the Dashboards service account's `KIBANA_PASSWORD`,
then run `docker compose up -d` in `apps/opensearch-dashboards/docker`.
Dashboards joins the OpenSearch network and listens at `https://localhost:5601`.
[OpenSearch Security initialization](https://docs.opensearch.org/latest/security/configuration/security-admin/)

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
