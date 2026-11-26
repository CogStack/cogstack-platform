# CogStack NGINX Helm chart

This chart exposes NGINX over HTTPS on port `443` through a `LoadBalancer`
Service. NGINX forwards requests to the cluster-internal HTTP Services in the
release namespace.

| HTTPS path | Backend | Client authentication |
| --- | --- | --- |
| `/nifi/`, `/nifi-api/` | NiFi on `8080` | NGINX Basic Auth |
| `/opensearch/` | OpenSearch on `9200` | OpenSearch Security |
| `/dashboards/` | OpenSearch Dashboards on `5601` | Dashboards login |

Load `nginx-tls` with `make -C deployment k3s-load-certs-nginx`, or provide a
TLS Secret and set `tls.existingSecret`. The certificate must cover the hostname
or IP that clients use. `NGINX_TLS_NAMES` controls the names when generating a
certificate with `make -C deployment certs-nginx`.

For NiFi, run `make -C deployment k3s-load-auth-nifi` to load the password hash
into `nifi-auth`. NGINX needs the `htpasswd` key in this Secret to grant access
to NiFi.

On K3s using ServiceLB, disable the bundled Traefik controller on all servers
with `--disable=traefik` to free port `443` for NGINX.

```bash
make -C deployment helm-install-nginx
```

For local access, set `service.type: ClusterIP` and forward the NGINX Service.

```bash
kubectl -n cogstack port-forward svc/cogstack-nginx 8443:443
```

Use `https://localhost:8443` with the trusted CA for the certificate.

Override `clusterDomain` if needed, or set `nifi.host`, `opensearch.host`,
`dashboards.host` and their corresponding `port` values to use other upstreams.
The optional `nginx-env` ConfigMap, loaded by `helm-install-nginx`, provides
`NGINX_NIFI_SERVER_NAME` from `deployment/env/nginx.env`.
