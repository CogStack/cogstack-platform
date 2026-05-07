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

### 1. Get the configuration files

Get the Terraform files for this example (the ZIP contains all `deployment-examples`; use the `openstack-kubernetes` folder for this guide).

[Download all deployment examples (ZIP)](../../../assets/downloads/deployment-examples.zip){ .md-button }

Alternatively you can view the file contents here:

#### k3s-cluster terraform files

This terraform configuration provisions VMs and installs k3s.

{{ embed_all_files_in_directory_as_snippets('openstack-kubernetes/k3s-cluster') }}

#### kubernetes-deployment terraform files

This terraform configuration deploys CogStack services to the cluster.

{{ embed_all_files_in_directory_as_snippets('openstack-kubernetes/kubernetes-deployment') }}

### 2. Add required secrets for your environment

Create a `terraform.tfvars` file, based on `terraform.tfvars.example`, containing the secrets for your environment.

### 3. Run Terraform

```bash
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

### 4. Accessing the CogStack Platform

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
