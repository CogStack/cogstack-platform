# Openstack Kubernetes Deployment

This Terraform example provides one stop approach to deploy the **CogStack** platform with its core components and observability stack in an OpenStack environment. It is specifically designed to simplify and automate the provisioning and configuration needed to run CogStack reliably and securely. 

This example:

- **Provisions Ubuntu VMs** in openstack
- **Installs Docker** on the VMs using Cloud-Init to manage containers easily
- **Installs Kubernetes using k3s** using Cloud-init

## Usage

### Requirements
- Terraform - [Install Terraform](https://developer.hashicorp.com/terraform/install)
- Openstack Cloud environment

### 1. Add Required Secrets for your env

Create a `terraform.tfvars` file, based on `terraform.tfvars.example`, containing the secrets for your environment. 

### 2. Run Terraform

```bash
# Create AKS cluster
cd k3s-cluster
terraform init
terraform apply --auto-approve

K3S_KUBECONFIG=$(terraform output -raw kubeconfig_file)

# Deploy services to kubernetes
cd ../kubernetes-deployment
export TF_VAR_kubeconfig_file=$K3S_KUBECONFIG
terraform init
terraform apply --auto-approve
```

Initial provisioning takes up to 10 minutes, where time is mostly downloading large docker images

### 3. Accessing the CogStack Platform

Once the deployment is complete and all services are running, you can access the CogStack platform and its components using the following URLs:

```bash
terraform output created_services
```

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
# Run Medcat service
helm install my-medcat oci://registry-1.docker.io/cogstacksystems/medcat-service-helm --wait --timeout 10m0s

# Find public url
kubectl get ingress
```

Access the k8s dashboard using
```
terraform output dashboard # Find the access token
kubectl -n kubernetes-dashboard port-forward svc/kubernetes-dashboard-kong-proxy 8443:443
```