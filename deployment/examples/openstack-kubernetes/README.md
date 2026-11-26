# Openstack Kubernetes Deployment

This Terraform example provides one stop approach to deploy the **CogStack** platform with its core components and observability stack in an OpenStack environment. It is specifically designed to simplify and automate the provisioning and configuration needed to run CogStack reliably and securely. 

This example:

- **Provisions Ubuntu VMs** in openstack
- **Installs Docker** on the VMs using Cloud-Init to manage containers easily
- **Installs Kubernetes using k3s** using Cloud-init

## Usage

### Requirements
- Terraform - [Install Terraform](https://developer.hashicorp.com/terraform/install)
- [kubectl](https://kubernetes.io/docs/tasks/tools/) and `envsubst` (part of GNU gettext)
- Openstack Cloud environment

### 1. Add Required Secrets for your env

Create a `terraform.tfvars` file, based on `terraform.tfvars.example`, containing the secrets for your environment. 

### 2. Run Terraform

The commands below assume this example folder is inside a clone of [cogstack-platform](https://github.com/CogStack/cogstack-platform), so the manifests are at `../../../kubernetes`.

```bash
# Create K3s cluster
cd k3s-cluster
terraform init
terraform apply --auto-approve

K3S_KUBECONFIG=$(terraform output -raw kubeconfig_file)

# Deploy CogStack with the plain manifests in deployment/kubernetes
export KUBECONFIG=$K3S_KUBECONFIG
export DOMAIN=cogstack.example.org
kubectl kustomize ../../../kubernetes | envsubst '${DOMAIN}' | kubectl apply -f -
kubectl -n cogstack get pods -w
```

Initial provisioning takes up to 10 minutes, where time is mostly downloading large docker images

### 3. Accessing the CogStack Platform

Once the deployment is complete and all services are running, you can access the CogStack platform and its components.

The manifests create an ingress with one host per app (`trainer.`, `jupyter.`, `dashboards.`, `medcat.`, `anoncat.` and `ocr.<DOMAIN>`), served by the cluster's default ingress controller (K3s ships with Traefik). Point DNS for those names at a cluster node to use them.

Alternatively, use `kubectl -n cogstack port-forward`; see the [deployment/kubernetes README](https://github.com/CogStack/cogstack-platform/tree/main/deployment/kubernetes) for the list of services and ports.

## Optionally use the K8s cluster as normal with the CLI
After setting up the cluster, it is possible to interact directly with it using the kubectl CLI

The requirement is to get the KUBECONFIG file created by the terraform apply.

```bash
# Get KUBECONFIG
K3S_KUBECONFIG=$(terraform output -raw kubeconfig_file)

# SET KUBECONFIG
export KUBECONFIG=${K3S_KUBECONFIG}
```

You can then interact with kubernetes via the CLI for example:

```bash
# See the CogStack pods
kubectl -n cogstack get pods

# Find public url
kubectl -n cogstack get ingress
```

Access the k8s dashboard using
```
terraform output dashboard # Find the access token
kubectl -n kubernetes-dashboard port-forward svc/kubernetes-dashboard-kong-proxy 8443:443
```