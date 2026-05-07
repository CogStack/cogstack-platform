# Azure AKS Deployment

<div class="tech-stack-banner" markdown="block">

{{ cogstack_banner_logo() }}

:material-microsoft-azure:{ .tech-icon-azure } :simple-kubernetes:{ .tech-icon-kubernetes } :simple-terraform:{ .tech-icon-terraform }

</div>

This is an example deployment of CogStack in Azure.

The recommended deployment of CogStack in Azure is based on using Kubernetes through Azure Kubernetes Service.

This example will create a AKS cluster, setup any necessary config, deploy CogStack to the cluster, and test that it is available. It will create publically accessible services, so is not suitable for production deployment.

We create a cluster following the Official Azure Verified Modules patterns in https://azure.github.io/Azure-Verified-Modules/indexes/terraform/tf-pattern-modules/ to create AKS clusters with their recommended defaults.


## Usage
Deployment through terraform is carried out through two terraform commands, to handle the sequencing issues between making a k8s cluster and using it in the cloud.

### Requirements
- Terraform - [Install Terraform](https://developer.hashicorp.com/terraform/install)
- Azure Credentials for an account and subscription that can create and destroy resources.

#### Required Permissions
- Contributor
- User Access Administrator
...
#### Required Features
- EncryptionAtHost: `az feature register --namespace Microsoft.Compute --name EncryptionAtHost`

### 1. Get the configuration files

All you need to do is get the Terraform files that have been preconfigured for this example (this download includes every `deployment-examples` tree; use the `azure-kubernetes` folder for this guide).

[Download all deployment examples (ZIP)](../../../assets/downloads/deployment-examples.zip){ .md-button }

Alternatively you can view the file contents here:

#### aks-cluster terraform files

This terraform configuration will create a new Azure AKS cluster.

{{ embed_all_files_in_directory_as_snippets('azure-kubernetes/aks-cluster') }}

#### kubernetes-deployment terraform files

This terraform configuration will use the helm provider to run services in kubernetes.

{{ embed_all_files_in_directory_as_snippets('azure-kubernetes/kubernetes-deployment') }}

### 2. Use the Azure CLI to login for your subscription
Run the az login command, which will open a web browser for you to login to your azure account. We then set the subscription ID for use by the Azure RM Terraform provider.

```bash
az login
export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
```

### 3. Run Terraform
Terraform is run on two modules, so we will run one terraform apply in one folder, then another terraform apply in a second folder.

Initial provisioning takes around 15 minutes.

```bash
# Create AKS cluster
cd aks-cluster
terraform init
terraform apply --auto-approve

AZURE_KUBECONFIG=$(terraform output -raw kubeconfig_file)

# Deploy services to kubernetes
cd ../kubernetes-deployment
export TF_VAR_kubeconfig_file=$AZURE_KUBECONFIG
terraform init
terraform apply --auto-approve
```

### 4. Accessing the CogStack Platform

Once the deployment is complete and all services are running, you can access the CogStack platform and its components using the following URLs:

TODO: Create a public ingress url
```bash
# terraform output service_urls
kubectl port-forward deployment/medcat-service-terraform-medcat-service-helm 5000:5000
http://localhost:5000/demo
```


### Optional - Destroy

You can destroy the infra to save costs when it wont be used for a long time.

```bash
cd ../kubernetes-deployment
terraform destroy

cd ../aks-cluster
terraform destroy
```


## Optionally use the K8s cluster as normal with the CLI
After setting up the cluster, it is possible to interact directly with it using the kubectl CLI

The requirement is to get the KUBECONFIG file created by the terraform apply.

```bash
# Get KUBECONFIG
cd aks-cluster
AZURE_KUBECONFIG=$(terraform output -raw kubeconfig_file)

# SET KUBECONFIG
export KUBECONFIG=${AZURE_KUBECONFIG}
```

Note - alternatively you could use the Azure CLI to set your kubeconfig using

```bash
MY_RESOURCE_GROUP_NAME=$(terraform output -raw resource_group_name)
MY_AKS_CLUSTER_NAME=$(terraform output -raw cluster_name)
az aks get-credentials --resource-group $MY_RESOURCE_GROUP_NAME --name $MY_AKS_CLUSTER_NAME`
```

You can then interact with kubernetes via the CLI for example:

```bash
# Run Medcat service
helm install my-medcat oci://registry-1.docker.io/cogstacksystems/medcat-service-helm --wait --timeout 10m0s

# Create the ingress
kubectl apply -f resources/ingress-medcat-service.yaml
# Find public url
kubectl get ingress
```
