# Azure AKS Deployment

This is an example deployment of CogStack in Azure. 

The recommended deployment of CogStack in Azure is based on using Kubernetes through Azure Kubernetes Service.

This example will create a AKS cluster, setup any necessary config, deploy CogStack Community to the cluster, and test that it is available. We will deploy the CogStack Community Edition in this tutorial, see here for everything you will get https://docs.cogstack.org/en/latest/cogstack-ce/_index/

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

### Steps

### 1. Use the Azure CLI to login for your subscription
Run the az login command, which will open a web browser for you to login to your azure account. We then set the subscription ID for use by the Azure RM Terraform provider. 

```bash
az login
export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
```

### 2. Run Terraform
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

### 3. Accessing the CogStack Platform

Once the deployment is complete and all services are running, you can access the CogStack platform and its components.

We will use kubernetes port-forwarding to make the services accessible locally.

Run this command:

```bash
terraform output -raw cogstack_notes | bash
```

The console will now print all the URLs you can visit to access your CogStack deployment.

<!-- termynal -->
```bash
$ terraform output -raw cogstack_notes | bash
Forwarding from 127.0.0.1:5001 -> 5000
Forwarding from [::1]:5001 -> 5000
Forwarding from 127.0.0.1:5000 -> 5000
Forwarding from [::1]:5000 -> 5000
Visit http://127.0.0.1:5000 to use MedCAT Service
Visit http://127.0.0.1:5001 to use AnonCAT
Visit http://127.0.0.1:8080 to use MedCAT Trainer
Visit https://127.0.0.1:9200 to use OpenSearch
Visit http://127.0.0.1:5601 to use OpenSearch Dashboards
Visit http://127.0.0.1:8000 to use jupyterhub
Visit http://127.0.0.1:8000/user/admin/notebooks/medcat-service-tutorial.ipynb to get started with a tutorial
```

### 4. Continue with the CogStack Tutorials

You've now got a fully working deployment of CogStack Community Edition!

Now you can look at the product tour and interactively follow along with this: https://docs.cogstack.org/en/latest/cogstack-ce/product-tour/ .

You've already port-forwarded the services, so you should be able to just open all the URLs and try out the applications.


### Optional - Destroy

You can destroy the infra to save costs when it wont be used for a long time.

Do note that there is an initial cost every time the EKS infrastructure is created, looks to be around $0.50 at time of writing.

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
helm install medcat-service oci://registry-1.docker.io/cogstacksystems/medcat-service-helm --wait --timeout 10m0s
```