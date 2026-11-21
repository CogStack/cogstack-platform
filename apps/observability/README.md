# Cogstack Observability Stack

This project runs a stack for observability of deployed software.

It provides the following features:
- Dashboards for availability
- Telemetry of infrastructure such as host memory usage, and elasticsearch index size
- Alerting based on a defined Service Level Objective (SLO) and burn rates
- Blackbox Probing of services to find service level indicators of uptime and latency
- A working inventory of what is running where

Image definitions and bundled configuration are in this directory. Deployment examples and quickstart smoke tests are in [deployment/examples/observability](../../deployment/examples/observability).

See the [full documentation](../../docs/docs/platform/observability/index.md).

## Local Development

From the repository root, run the stack locally with
```
cd ./deployment/examples/observability/simple
docker compose up -d --remove-orphans
```

This will start the observability stack, set to probe and monitor itself.

Access Grafana on `http://localhost/grafana`

The stack uses the [shared NGINX image](../nginx) with its observability profile.
For local rebuilds, build the proxy separately from the repository root with
`docker build -t cogstacksystems/cogstack-nginx:latest apps/nginx`.
Host port 80 maps to NGINX port 8001; the existing Grafana, Prometheus and Alloy
URLs are retained. Availability probes run through NGINX. The former Traefik
metrics scrape and dashboard are removed; proxy timings are in NGINX access logs.
When upgrading an existing stack, remove its orphaned `traefik` container with
`docker compose up -d --remove-orphans`. Retained Grafana volumes may still hold
the old Traefik dashboard because the default dashboard provider disables deletion.
