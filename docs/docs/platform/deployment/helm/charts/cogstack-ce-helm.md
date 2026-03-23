# CogStack CE Helm Chart

This page documents the Helm chart for **CogStack Community Edition (CogStack CE)**.

CogStack CE is an “umbrella” chart that deploys the full stack needed for the community edition:

- MedCAT service
- AnonCAT (MedCAT in DeID mode)
- MedCAT Trainer (+ required supporting infrastructure)
- OpenSearch (+ dashboards)
- JupyterHub (with example notebooks)

## Installation

Install the chart (Helm release name: `cogstack`):

```sh
helm install cogstack oci://registry-1.docker.io/cogstacksystems/cogstack-helm-ce --wait --timeout 10m0s
```

If you want to install into a dedicated namespace:

```sh
helm install cogstack oci://registry-1.docker.io/cogstacksystems/cogstack-helm-ce \
  --namespace cogstack --create-namespace \
  --wait --timeout 10m0s
```

## Port-forwarding (local access)

After installing, set up port-forwarding using the chart’s NOTES template:

```sh
helm get notes cogstack | bash
```

This runs `kubectl port-forward` in the background and exposes:

- MedCAT Service: `http://127.0.0.1:5000`
- AnonCAT: `http://127.0.0.1:5001`
- MedCAT Trainer: `http://127.0.0.1:8080`
- OpenSearch (if enabled): `http://127.0.0.1:9200`
- OpenSearch Dashboards (if enabled): `http://127.0.0.1:5601`
- JupyterHub (if enabled): `http://127.0.0.1:8000`

Open the bundled notebook directly at:

- http://127.0.0.1:8000/user/admin/notebooks/medcat-service-tutorial.ipynb

## Configuration and customization

You can customize the deployment by providing a `values.yaml` override file to `helm install` or `helm upgrade`.

Typical example:

```sh
helm upgrade cogstack oci://registry-1.docker.io/cogstacksystems/cogstack-helm-ce \
  --namespace cogstack \
  -f my-values.yaml
```

### Component enablement

Use these boolean flags to enable/disable major components:

- `medcat-service.enabled`
- `anoncat-service.enabled`
- `medcat-trainer.enabled`
- `opensearch.enabled`
- `opensearch-dashboards.enabled`
- `cogstack-jupyterhub.enabled`

### MedCAT service (demo UI and replicas)

Common values:

- `medcat-service.replicasCount`
- `medcat-service.env.APP_ENABLE_DEMO_UI` (demo mode UI)
- `medcat-service.image.repository`
- `medcat-service.image.tag`

### AnonCAT (DeID mode and replicas)

Common values:

- `anoncat-service.replicasCount`
- `anoncat-service.env.DEID_MODE`
- `anoncat-service.env.DEID_REDACT`
- `anoncat-service.image.repository`
- `anoncat-service.image.tag`

### MedCAT Trainer (CSRF trusted origins)

The Trainer frontend requires the correct CSRF trusted origins for your access pattern:

- `medcat-trainer.env.CSRF_TRUSTED_ORIGINS`

If you access Trainer via the standard local port-forward (`http://127.0.0.1:8080`), the chart default is usually suitable. If your port-forward differs, update this value accordingly.

### JupyterHub (dummy authentication)

By default, the community chart uses a dummy authenticator intended for local/non-production use:

- `cogstack-jupyterhub.jupyterhub.hub.config.Authenticator.admin_users` (default: `["admin"]`)
- `cogstack-jupyterhub.jupyterhub.hub.config.DummyAuthenticator.password` (default: `SuperSecret`)

Do not rely on these settings for production deployments.

### OpenSearch initial credentials

OpenSearch is deployed with an initial admin password set via:

- `opensearch.extraEnvs` (contains `OPENSEARCH_INITIAL_ADMIN_PASSWORD`)

Update this to something secure for non-demo environments.

### Image pull secrets

If you use private registries, configure:

- `imagePullSecrets`

## Uninstall

```sh
helm uninstall cogstack --namespace cogstack
```

If you created the namespace only for this release:

```sh
kubectl delete namespace cogstack
```

