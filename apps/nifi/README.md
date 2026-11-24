# CogStack NiFi

CogStack's Apache NiFi image bundles Python processors, JDBC drivers, schemas,
and example ingestion flows. The Docker stack serves NiFi over HTTPS through
[CogStack NGINX](../nginx/README.md).

## Docker setup

Use Docker Compose v2 with support for `include`, and Make. The default and
production configurations use `cogstacksystems/nifi` and `cogstacksystems/nginx`.

### Environment files

From the repository root, create `apps/nifi/env/` and add `general.env` and
`nifi.env`. Both files are Git-ignored. `general.env` can be empty if you have
no shared settings. Use the following as a starting point for `nifi.env`.

```dotenv
NIFI_DOCKER_CPU_MIN=1
NIFI_DOCKER_CPU_MAX=2
NIFI_DOCKER_RAM=4g

NIFI_WEB_PROXY_HOST=localhost:8443
NIFI_HEALTHCHECK_HOST=nifi
```

Set `KEYSTORE_PASSWORD` and `TRUSTSTORE_PASSWORD` to match the mounted stores.
Set `SINGLE_USER_CREDENTIALS_USERNAME` and `SINGLE_USER_CREDENTIALS_PASSWORD`
for the NiFi login. Use at least 12 characters for the single-user password.
Use `COGSTACK_NIFI_ENV_FILE` to select another deployment's `nifi.env`.

The dev Make targets take their sample store passwords and login from
[`certificates_dev.env`](../../deployment/env/certificates_dev.env) and
[`authentication_dev.env`](../../deployment/env/authentication_dev.env).
Set your own values in `nifi.env` to override the samples.

Preserve `NIFI_SENSITIVE_PROPS_KEY` with the flow configuration so NiFi can
decrypt saved sensitive properties. For a non-local deployment, set
`NIFI_WEB_PROXY_HOST` to the browser-facing host and port. If you change
`NIFI_EXTERNAL_PORT_NGINX`, update that allowlist entry as well. See
[Apache's startup script](https://github.com/apache/nifi/blob/rel/nifi-2.12.0/nifi-docker/dockerhub/sh/start.sh)
and [Docker setup guide](https://github.com/apache/nifi/blob/rel/nifi-2.12.0/nifi-docker/dockerhub/README.md)
for additional settings.

### TLS certificates

Use the existing certificate generators or supply a TLS bundle. Place the files
under `deployment/security/certificates/`, or set `SECURITY_DIR` in `nifi.env`
to the parent of your deployment’s `certificates/` directory.

| Files | Purpose |
| --- | --- |
| `nifi/nifi-keystore.jks`, `nifi/nifi-truststore.jks` | NiFi's server identity and truststore. The server certificate must cover the upstream TLS name, `nifi` by default, and the health check hostname. |
| `nginx/tls.crt`, `nginx/tls.key` | NGINX server identity for the hostname users open in their browser. The browser must trust its issuer. |
| `root/root-ca.pem` | Public CA used by NGINX and the NiFi health check to verify NiFi's server certificate. |

Compose mounts the service certificate directories and `root/root-ca.pem` read-only.
The CA signing key and private bundles stay on the host. Make the mounted files
readable by their container users. The start targets check for readable,
nonempty files before launching. Certificate validation occurs when the services
connect over TLS.

### Start and verify

Run these commands from `apps/nifi/docker/`:

| Command | Configuration |
| --- | --- |
| `make check-config` | Resolve and validate all three Compose configurations using the env files. |
| `make start-nifi` | Use `docker-compose.yml` to start published images with a Compose-managed `cogstack-net`. |
| `make start-nifi-dev` | Start NiFi and NGINX with the dev settings. |
| `make start-nifi-dev-build` | Apply `docker-compose.dev.yml` over the base, build both images locally, mount editable NiFi resources and dev data, and use `nifi-dev-net`. |
| `make start-nifi-prod` | Apply `docker-compose.prod.yml` over the base and start published images on an existing `cogstack-net`. |

Default and prod use Compose project `nifi` and share its named volumes. Dev uses
separate volumes by default. To pin the published images, set `NIFI_IMAGE` and
`NIFI_NGINX_IMAGE` to specific tags or digests. Compose automatically loads a
local `docker-compose.override.yml` with the default entry point. For dev or
prod, pass additional overrides as the last `-f` argument when running Compose
directly.

Startup runs in the background. With the example settings and working TLS, open
`https://localhost:8443/nifi/` through NGINX. To check the default stack's health
and logs from the same directory:

```bash
source ./export_env_vars.sh
docker compose ps
docker compose logs --tail=100 nifi nifi-nginx
```

For dev or prod, add `-f docker-compose.base.yml -f docker-compose.dev.yml` or
`-f docker-compose.base.yml -f docker-compose.prod.yml` after `docker compose`.
NiFi checks its local HTTPS API and NGINX checks the upstream path to NiFi. Dev
also publishes NiFi directly on port `8082` by default. Its host data directory
is `apps/nifi/data/` unless overridden by `NIFI_DATA_PATH`, and processors see
it at `/data/`. Add a deployment-specific mount if a published-image flow needs
host data.

### Storage and cleanup

The base configuration keeps seven named volumes for configuration, state,
logs, and the database, FlowFile, content, and provenance repositories. Use
`make stop-nifi-dev`, `make stop-nifi-prod`, or `docker compose stop` for the
default stack after sourcing the env files. `make delete-nifi` removes the
**dev** containers and preserves their volumes. `make delete-nifi-dev-volumes`
also deletes their named storage, including saved flows and queued data. Back
up FlowFile and content repositories together when preserving queues.

## Build the image

From the repository root:

```bash
docker build --tag cogstacksystems/nifi:local apps/nifi
```

The image installs Python dependencies from `uv.lock` and uses Apache's startup
scripts and configuration, with TLS reload and shutdown settings adjusted in the
Dockerfile. [`conf/`](conf/) is reference configuration. The build context
excludes it along with local env files and runtime state.

Override `NIFI_BASE_IMAGE` and `NIFI_VERSION` together when changing the Apache
version. `GROOVY_VERSION`, `NIFI_UID`, and `NIFI_GID` can also be overridden.

## Processors and flow resources

| Path | Contents |
| --- | --- |
| [`user_python_extensions/`](user_python_extensions/) | NiFi 2 native Python processors. See the [sample processor](user_python_extensions/sample_processor.py). |
| [`user_scripts/`](user_scripts/) | Shared `nifi.user_scripts` modules, standalone processors, integration examples, and older scripts. |
| [`drivers/`](drivers/) | DuckDB, MySQL, PostgreSQL, and SQL Server JDBC drivers. |
| [`user_schemas/`](user_schemas/) | Search settings and schema examples. |
| [`user_templates/`](user_templates/) | NiFi JSON process groups and legacy XML templates. |

The image places scripts, drivers, schemas, and templates under `/opt/nifi/`
with the same directory names. Native Python extensions are discovered in
`/opt/nifi/nifi-current/python_extensions`.

Upload a top-level JSON flow as a process group in the NiFi UI. Configure its
controller services, endpoints, and credentials before enabling the group.
Depending on the example, this may require OpenSearch, PostgreSQL, Azure Blob
Storage, OCR, or MedCAT. Legacy XML templates and schemas are migration
references. Some include older driver names and service paths.

For the JSON record schema converter, set `json_mapper_schema_path` explicitly.
The bundled common mapping is at
`/opt/nifi/user_schemas/legacy/cogstack_common_schema_mapping.json`.

## Python development

Use Python 3.11 or later and the `uv` version required by
[`pyproject.toml`](pyproject.toml). From `apps/nifi/`:

```bash
uv sync --locked --dev
uv run --locked ruff check user_python_extensions --select F,E9
uv run --locked mypy --config-file pyproject.toml user_python_extensions
```

Set your editor's Pyright project to [`pyrightconfig.json`](pyrightconfig.json).
The project uses the local `.venv` and [`typings/`](typings/) for NiFi API and Py4J
stubs. The real `nifiapi` runtime is supplied by NiFi. The package maps this
application directory to the `nifi` namespace. Add new subpackages to
`tool.setuptools.packages` when they need to be installed.

The commands above check the native extensions. Files under
[`user_scripts/tests/`](user_scripts/tests/) also include integration scripts
with external service, credential, or sample data requirements.

## Kubernetes

The [NiFi chart](../../deployment/charts/nifi/README.md) and
[NGINX chart](../../deployment/charts/nginx/README.md) document their ConfigMaps,
TLS Secrets, and storage. Use those instructions for Helm deployments.

## Dependency auditing

From the repository root, audit the docs and NiFi lockfiles using `uv` and
`pip-audit` on `PATH`:

```bash
bash deployment/scripts/maintenance/audit_pip_dependency.sh --include-nifi
```

See the [deployment scripts README](../../deployment/scripts/README.md) for
prerequisites.
