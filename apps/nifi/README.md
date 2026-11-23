# CogStack NiFi

The CogStack NiFi image, Python processors, JDBC drivers, schemas and flow
templates. These files were migrated from the `nifi/` directory of
`cogstack_nifi`; the Python project metadata, lockfile and type stubs now live
alongside the application.

## Contents

| Path | Purpose |
| --- | --- |
| `Dockerfile` | Build the customised Apache NiFi image. |
| `pyproject.toml`, `uv.lock` | Python package configuration and locked dependencies. |
| `pyrightconfig.json` | Pyright configuration for the local virtual environment, imports and type stubs. |
| `user_python_extensions/` | NiFi 2 Python processors. |
| `user_scripts/` | Shared Python utilities, processors and legacy scripts. |
| `drivers/` | JDBC drivers bundled in the image. |
| `user_schemas/`, `user_templates/` | Schemas and example ingestion flows. |
| `conf/` | Reference configuration from the original application. |
| `docker/` | Container health check and deployment helpers. |
| `typings/` | NiFi API and Py4J stubs for local type checking. |

## Build the image

Run from the platform repository root:

```bash
docker build --tag cogstacksystems/nifi:local apps/nifi
```

`apps/nifi` is the build context. The Dockerfile uses the checked-in dependency
lockfile and bundles the application resources. It keeps Apache's default
configuration and startup scripts; host configuration and environment files are
excluded from the build context.

The `NIFI_BASE_IMAGE`, `NIFI_VERSION`, `GROOVY_VERSION`, `NIFI_UID` and `NIFI_GID`
build arguments can override the Dockerfile defaults. Keep the base image and
`NIFI_VERSION` aligned. Published image names and container resource paths such
as `/opt/nifi/user_scripts` remain the same.

## Python development

Use Python 3.11 or later and a version of `uv` satisfying
`tool.uv.required-version` in `pyproject.toml`:

```bash
uv sync --directory apps/nifi --locked --dev
uv run --directory apps/nifi --locked ruff check user_python_extensions --select F,E9
uv run --directory apps/nifi --locked mypy --config-file pyproject.toml user_python_extensions
```

The package maps this application directory to the existing `nifi` Python
namespace, so imports such as `nifi.user_scripts.utils.generic` continue to work
after installation. When adding Python subpackages, include them in
`tool.setuptools.packages`. Native NiFi processors run inside NiFi, which supplies
the `nifiapi` framework; `typings/` contains stubs for development.

Some files under `user_scripts/tests/` are integration tests or example scripts
requiring running services, credentials and sample data.

For Pyright, use `apps/nifi/pyrightconfig.json` as the project configuration. It
uses the application's `.venv`, resolves the `nifi` package from the parent
`apps/` directory, and includes the local processor and type-stub directories.

## Deployment helpers

The Kubernetes charts live in
[`deployment/charts/nifi`](../../deployment/charts/nifi/README.md)
and [`deployment/charts/nginx`](../../deployment/charts/nginx/README.md). Their
READMEs describe the required environment ConfigMaps, TLS Secrets and storage.

NiFi and NGINX share service settings, TLS mounts and volumes in
`docker/docker-compose.base.yml`. Run these commands from `apps/nifi/docker`:

| Command | Configuration |
| --- | --- |
| `make check-config` | Validate default, dev and prod without starting containers. |
| `make start-nifi-dev-build` | Apply `docker-compose.dev.yml` over the base. Build both images locally, mount NiFi source and dev data, and use `nifi-dev-net`. |
| `source ./export_env_vars.sh && docker compose up -d` | Use `docker-compose.yml` to run published images on a Compose-managed `cogstack-net`. |
| `make start-nifi-prod` | Apply `docker-compose.prod.yml` over the base. Run published images on an existing `cogstack-net`. |

Set `NIFI_IMAGE` and `NIFI_NGINX_IMAGE` to pin image references for default or
prod. Both publish NiFi through NGINX, and dev also exposes NiFi directly.
Compose uses `docker-compose.override.yml` with the default entry point if you
add one. Append an explicit `-f` for any additional dev or prod overrides.

Provide `env/general.env`, `env/nifi.env`, NiFi credentials and TLS certificates
before starting the stack. For a published-image deployment, make the mounted
files readable by the image users and set `NIFI_WEB_PROXY_HOST` for the public
host and port. The image build above works independently of these files.

Place these files under `deployment/security/certificates/`:

- `nifi/nifi-keystore.jks` and `nifi/nifi-truststore.jks` for NiFi.
- `nginx/tls.crt` and `nginx/tls.key` for the NGINX public hostname.
- `root/root-ca.pem` for both containers to verify NiFi. Keep `root/` limited to public CA material.

Compose mounts the directories read-only. Git ignores the certificate contents.
Supply any ingestion-specific certificate mounts or host overrides in the deployment
that needs them.

Mutable configuration, data repositories, processor logs and databases belong
in deployment-owned storage. The image health check expects the configured TLS
CA certificate at runtime.

## Dependency auditing

From the platform repository root, audit the documentation and NiFi dependency
lockfiles with `uv` and `pip-audit` available on `PATH`:

```bash
bash deployment/scripts/maintenance/audit_pip_dependency.sh --include-nifi
```

See the [deployment scripts README](../../deployment/scripts/README.md) for
prerequisites.
