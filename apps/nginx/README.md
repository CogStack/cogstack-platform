# CogStack NGINX

One image with NiFi, MedCAT-trainer and observability configurations, selected per container.
It uses the upstream image's entrypoint, environment substitution and DNS
resolver discovery. There is no custom entrypoint or configuration framework.

Adapted from [CogStack/CogStack-NiFi services/nginx](https://github.com/CogStack/CogStack-NiFi/tree/71b3d483747a504986205addb4d2b17f58f19a0b/services/nginx)
at `71b3d483747a504986205addb4d2b17f58f19a0b`. NiFi routes are retained;
startup uses NGINX's existing implementation and the health check invokes curl.
Trainer routes come from the existing MedCAT-trainer Helm chart. These are
modified copies; see `LICENSE`.

Build from the repository root:

```bash
docker build -t cogstacksystems/nginx:local apps/nginx
```

The image is published independently by [docker_build_nginx.yml](../../.github/workflows/docker_build_nginx.yml)
as `cogstacksystems/nginx` for `linux/amd64` and `linux/arm64`.

Select the configuration with the upstream image's variable:

| Application | `NGINX_ENVSUBST_TEMPLATE_DIR` |
| --- | --- |
| NiFi (default) | `/etc/nginx/templates/nifi` |
| MedCAT-trainer | `/etc/nginx/templates/medcat-trainer` |
| Observability | `/etc/nginx/templates/observability` |

All environment defaults are declared in `Dockerfile`. Treat template values
as trusted deployment configuration. The substitution filter preserves NGINX
variables such as `$host`.

For NiFi, mount the frontend certificate/key at `/certificates/nifi/nifi.pem`
and `/certificates/nifi/nifi.key`, and the upstream CA at
`/certificates/root/root-ca.pem`. Set `NIFI_UPSTREAM_HOST`,
`NIFI_UPSTREAM_PORT`, `NIFI_UPSTREAM_TLS_NAME` and `NIFI_WEB_PROXY_PORT` for
the deployment. TLS verification stays enabled. An optional
`NGINX_PROXY_CONTEXT_PATH` must start with `/` and have no trailing slash.

For MedCAT-trainer, mount static/media directories at `/home/api/static` and
`/home/api/media`. Set `MEDCAT_UPSTREAM_HOST` and `MEDCAT_SOLR_HOST` to the
backend service names. Defaults use ports 8000 and 8983, with NGINX listening
on 8001. In a trainer Pod, the backend host can remain `127.0.0.1`. The
configuration preserves Solr path rewriting, gzip, the `4000m` upload limit
and `3000s` read/send timeouts for model loading and transfers. Connections
use NGINX's default `60s` timeout; idle client keepalive uses `65s`.
TLS terminates at the deployment's external gateway.

For observability, NGINX listens on 8001 and routes `/grafana/`, `/prometheus/`
and `/alloy/` to their Compose services. Grafana's prefix is stripped;
Prometheus and Alloy prefixes are preserved.

Access logs include request time (`rt`), upstream response time (`urt`) and
upstream status (`us`).

The image runs as UID/GID `1000:1000`; build arguments `NGINX_UID` and
`NGINX_GID` can change them. Mount readable certificates and files. A read-only
root filesystem works with writable `/tmp`; size temporary storage for the
deployment's buffered uploads and responses.

Health endpoints listen on loopback port 8080 (`NGINX_HEALTH_PORT`).
`/healthz/live` checks NGINX alone; `/healthz/ready` checks the application
backend. Docker's health check uses readiness; Kubernetes exec probes can
call curl directly. The health port must differ from the application port.
Existing chart image defaults are unchanged.
