# Quickstart

This tutorial installs CogStack CE using the plain Kubernetes manifests in [`deployment/kubernetes`](https://github.com/CogStack/cogstack-platform/tree/main/deployment/kubernetes), sets up port-forwarding, and opens the bundled JupyterHub in your browser.

The install should take around 15 minutes, and by the end of this tutorial you will have a fully working and integrated CogStack environment that you can start using.

## Prerequisites

- A Kubernetes cluster
- `kubectl` (kustomize is built in)
- `envsubst` (part of GNU gettext)
- `git`

One easy option to get a local kubernetes is to use minikube, see https://minikube.sigs.k8s.io/docs/start/ for a guide. If you're running docker desktop, it also makes it easy to run one.

## 1. Install CogStack CE

Run:

```sh
git clone https://github.com/CogStack/cogstack-platform.git
cd cogstack-platform
export DOMAIN=cogstack.example.org
kubectl kustomize deployment/kubernetes | envsubst '${DOMAIN}' | kubectl apply -f -
kubectl -n cogstack get pods -w
```

This installs CogStack Community Edition into the `cogstack` namespace with the default settings. `DOMAIN` is only used for the ingress hostnames (`trainer.`, `jupyter.`, `dashboards.`, `medcat.`, `anoncat.` and `ocr.<DOMAIN>`); you can leave it as the example value when using port-forwarding.

!!! warning
    For brand new installations, this might take a while, so expect up to 15 minutes. It needs to download many GB of docker images first and then startup processes.

    Once the initial installation is done, then any updates should be significantly faster.

    The defaults (including passwords) are for evaluation. See [Kubernetes manifests](../../platform/deployment/kubernetes.md) for how to customise them.

## Port-forward and open JupyterHub

1. Set up the port-forwarding endpoints for the services:

```sh
kubectl -n cogstack port-forward svc/medcat-service 5000:5000 &
kubectl -n cogstack port-forward svc/anoncat-service 5001:5000 &
kubectl -n cogstack port-forward svc/ocr-service 8090:8090 &
kubectl -n cogstack port-forward svc/medcat-trainer 8001:8001 &
kubectl -n cogstack port-forward svc/opensearch 9200:9200 &
kubectl -n cogstack port-forward svc/opensearch-dashboards 5601:5601 &
kubectl -n cogstack port-forward svc/jupyterhub 8000:8000 &
```

These run `kubectl port-forward` in the background. The apps are then available at:

| App | URL |
| --- | --- |
| MedCAT Service | http://127.0.0.1:5000 |
| AnonCAT | http://127.0.0.1:5001 |
| OCR Service | http://127.0.0.1:8090 |
| MedCAT Trainer | http://127.0.0.1:8001 |
| OpenSearch | https://127.0.0.1:9200 (user `admin`, password `opensearch-312$A`) |
| OpenSearch Dashboards | http://127.0.0.1:5601 |
| JupyterHub | http://127.0.0.1:8000 (any username, password `SuperSecret`) |

2. Open JupyterHub by opening http://127.0.0.1:8000 in a web browser

Jupyter should start up, and present a login screen.

## Next step: run the bundled notebook

Continue with: [Tutorial: Open and operate JupyterHub](./end-to-end-jupyterhub.md).
