# CogStack Community Edition on Kubernetes

Plain Kubernetes manifests for CogStack Community Edition (CE). There is no Helm
chart: what you see in these `.yaml` files is what gets applied.

## What's deployed

Everything goes into the `cogstack` namespace:

| Service | Manifest | What it is |
| --- | --- | --- |
| `medcat-service` | `medcat-service.yaml` | MedCAT NLP API with an example model pack |
| `anoncat-service` | `anoncat-service.yaml` | MedCAT service configured for de-identification (AnonCAT) |
| `ocr-service` | `ocr-service.yaml` | OCR service for documents and images |
| `medcat-trainer` | `medcat-trainer.yaml` | MedCAT Trainer with NGINX, PostgreSQL and Solr |
| `opensearch` | `opensearch.yaml` | Single-node OpenSearch |
| `opensearch-dashboards` | `opensearch-dashboards.yaml` | OpenSearch Dashboards |
| `opensearch-provisioning` | `opensearch-provisioning.yaml` | Job that loads synthetic example data and dashboards |
| `jupyterhub` | `jupyterhub.yaml` | JupyterHub with the example notebooks from `files/notebooks/` |
| ingress | `ingress.yaml` | One host per app under `${DOMAIN}` |

`kustomization.yaml` only sets the namespace and turns the files under `files/` into ConfigMaps.

## Deploy

Requires `kubectl` (with built-in kustomize) and `envsubst` (from GNU gettext). Run from a clone of
[cogstack-platform](https://github.com/CogStack/cogstack-platform):

```bash
export DOMAIN=cogstack.example.org   # apps at trainer., jupyter., dashboards., medcat., anoncat., ocr.<DOMAIN>
kubectl kustomize deployment/kubernetes | envsubst '${DOMAIN}' | kubectl apply -f -
kubectl -n cogstack get pods -w
```

The ingress uses the cluster's default ingress class; TLS and authentication are left to the ingress controller.

## Access without an ingress controller

Use `kubectl -n cogstack port-forward svc/<name> <port>` and open `http://localhost:<port>`:

| Service | Port | Notes |
| --- | --- | --- |
| `medcat-service` | 5000 | |
| `anoncat-service` | 5000 | Forward to a different local port, e.g. `5001:5000` |
| `ocr-service` | 8090 | |
| `medcat-trainer` | 8001 | User `admin`, password `admin` |
| `opensearch` | 9200 | HTTPS, user `admin`, password `opensearch-312$A` |
| `opensearch-dashboards` | 5601 | Same credentials as OpenSearch |
| `jupyterhub` | 8000 | Log in as any user with password `SuperSecret` |

These default credentials are for evaluation only. Change them before exposing the services.

## Customise

Edit the YAML directly: image versions, resources, environment variables, credentials and
storage are all set in the manifest for each service. Remove an app by deleting its
entry from `resources:` in `kustomization.yaml` (and its host in `ingress.yaml`).
Re-run the deploy command to apply changes.

## Acceptance test

An in-cluster Job checks that each service answers and that the example model packs return
the expected annotations:

```bash
kubectl -n cogstack delete job acceptance --ignore-not-found
kubectl -n cogstack apply -f deployment/kubernetes/tests/acceptance.yaml
kubectl -n cogstack wait --for=condition=complete job/acceptance --timeout=10m
kubectl -n cogstack logs job/acceptance
```

## Remove

```bash
kubectl delete namespace cogstack
```
