# NiFi NGINX Helm chart

Deploys `cogstacksystems/nifi-nginx` as the TLS reverse proxy for the NiFi web
Service. It creates a Deployment, a Service, an upstream-settings ConfigMap and
an optional Ingress.

## Prerequisites

Prepare these resources in the release namespace before installing:

| Resource | Default name | Required contents |
| --- | --- | --- |
| ConfigMap | `nginx-env` | Deployment-specific NGINX environment settings. |
| ConfigMap | `nifi-env` | Shared NiFi environment settings. |
| Secret | `cogstack-root-ca` | `ca.crt`, the public CA for upstream TLS verification. |
| TLS Secret | `nginx-tls` | `tls.crt` and `tls.key` for the proxy certificate. |

The environment ConfigMap names are currently fixed in the template. Override
certificate Secret names with `tls.rootCASecret` and `tls.existingSecret`.
The chart references these inputs rather than creating them from host files.

By default, the proxy connects to
`cogstack-nifi.<release-namespace>.svc.cluster.local:8443`, which matches the
Service from `deployment/charts/nifi`. Set `nifi.host` and `nifi.port`
for another upstream. `nifi.tlsName` must match the upstream certificate's TLS
name; it defaults to `nifi`.

## Render and install

Run from the platform repository root:

```bash
helm lint ./deployment/charts/nginx
helm template cogstack-nginx ./deployment/charts/nginx --namespace cogstack
helm upgrade --install cogstack-nginx ./deployment/charts/nginx \
  --namespace cogstack --create-namespace
```

Pass deployment overrides with `-f /path/to/nginx-values.yaml`. Set `image.tag`
to the image release required by the deployment.

## Optional Ingress

Ingress is disabled by default. Example deployment values:

```yaml
ingress:
  enabled: true
  className: nginx
  annotations:
    nginx.ingress.kubernetes.io/backend-protocol: HTTPS
  hosts:
    - host: nifi.example.org
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: nifi-ingress-tls
      hosts:
        - nifi.example.org
```

Configure annotations for the selected Ingress controller and provide any
referenced TLS Secret in the namespace. The chart's Service uses HTTPS on
`nginx.internalPort`, which defaults to `8443`.

## Environment-based values

`values.yaml` contains reusable defaults. `values.env.yaml` is an optional
`envsubst` input for deployment ports, upstream TLS name and resource limits.
Populate all referenced variables and render it to a separate values file before
passing it to Helm; Helm does not expand `${VARIABLE}` placeholders.

The chart currently uses fixed `cogstack-nginx` resource names. Use separate
namespaces for independent deployments.
