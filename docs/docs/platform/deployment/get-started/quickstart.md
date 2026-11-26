
# Quickstart

A local setup guide for running k8s locally, and installing CogStack with plain Kubernetes manifests


## Requirements
- Docker installed ([install Docker](https://docs.docker.com/get-docker/))
- Docker Compose installed ([install Docker Compose](https://docs.docker.com/compose/install/))
- A terminal with network access

## Setup

1. **Install Minikube**

You can install Minikube by following the official instructions:  
https://minikube.sigs.k8s.io/docs/start/

Or just run this if on linux:

```bash
curl -LO https://github.com/kubernetes/minikube/releases/latest/download/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube && rm minikube-linux-amd64
```

2. **Start Minikube**

```bash
minikube start
```

This will create a local Kubernetes cluster. You will also need [kubectl](https://kubernetes.io/docs/tasks/tools/) and `envsubst` (part of GNU gettext).

## Deploy CogStack

From a clone of [cogstack-platform](https://github.com/CogStack/cogstack-platform), apply the plain Kubernetes manifests:

```bash
export DOMAIN=cogstack.example.org
kubectl kustomize deployment/kubernetes | envsubst '${DOMAIN}' | kubectl apply -f -
```

This deploys CogStack Community Edition into the `cogstack` namespace. The first start downloads several GB of images, so allow up to 15 minutes.

### Verify deployment

Check that the pods are running:

```bash
kubectl -n cogstack get pods
```

Then run the in-cluster acceptance test:

```bash
kubectl -n cogstack apply -f deployment/kubernetes/tests/acceptance.yaml
kubectl -n cogstack wait --for=condition=complete job/acceptance --timeout=10m
kubectl -n cogstack logs job/acceptance
```

You’re now running CogStack locally on Kubernetes! For more detailed usage, see [Kubernetes manifests](../kubernetes.md).

### Access the service

Port-forward a service and open it in your browser, for example MedCAT Service at http://localhost:5000:

```bash
kubectl -n cogstack port-forward svc/medcat-service 5000:5000
```
