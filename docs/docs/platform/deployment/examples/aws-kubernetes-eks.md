# AWS EKS Deployment

<div class="tech-stack-banner" markdown="block">

{{ cogstack_banner_logo() }}

:material-aws:{ .tech-icon-aws } :simple-kubernetes:{ .tech-icon-kubernetes } :simple-terraform:{ .tech-icon-terraform }

</div>

This is an example deployment of CogStack in AWS. It will create publically accessible services, so is not suitable for production deployment.

The recommended deployment in AWS is based on using Kubernetes through AWS EKS.

This example will create a AWS EKS cluster, setup any necessary config, deploy CogStack to the cluster, and test that it is available.

## Usage
Deployment through terraform is carried out through two terraform commands, to handle the sequencing issues between making a k8s cluster and using it in AWS.

### Requirements
- Terraform - [Install Terraform](https://developer.hashicorp.com/terraform/install)
- AWS Credentials for an account that can create and destroy resources.

### 1. Get the configuration files

All you need to do is get the Terraform files that have been preconfigured for this example (the ZIP contains every `deployment-examples` tree; use the `aws-kubernetes` folder for this guide).

[Download all deployment examples (ZIP)](../../../assets/downloads/deployment-examples.zip){ .md-button }

Alternatively you can view the file contents here:

#### eks-cluster terraform files

This terraform configuration will create a new AWS EKS cluster.

{{ embed_all_files_in_directory_as_snippets('aws-kubernetes/eks-cluster') }}

#### kubernetes-deployment terraform files

This terraform configuration will use the helm plugin to run services in kubernetes.

{{ embed_all_files_in_directory_as_snippets('aws-kubernetes/kubernetes-deployment') }}

### 2. Add required secrets for your environment
This readme uses environment variables for access:

1. See the `.env.example` file for the required details.
2. Create a file `.env` with those fields set for your account. 
3. Execute `source .env` to set those environment variables

If desired, see the official documentation for other ways to provide AWS credentials https://registry.terraform.io/providers/hashicorp/aws/latest/docs#authentication-and-configuration

### 3. Run Terraform
Terraform is run on two modules for AWS, so we will run one terraform apply in one folder, then another terraform apply in a second folder. 

Initial provisioning takes around 15 minutes.

```bash
# Set AWS credentials 
source .env

# Create AWS EKS infra
cd eks-cluster
terraform init
terraform apply --auto-approve

AWS_KUBECONFIG=$(terraform output -raw kubeconfig_file)

# Deploy services to kubernetes
cd ../kubernetes-deployment
export TF_VAR_kubeconfig_file=$AWS_KUBECONFIG
terraform init
terraform apply --auto-approve
```

### 4. Accessing the CogStack Platform

Once the deployment is complete and all services are running, you can access the CogStack platform and its components using the following URLs:

```bash
terraform output service_urls
```


### Optional - Destroy

You can destroy the infra to save costs when it wont be used for a long time.

Do note that there is an initial cost every time the EKS infrastructure is created, looks to be around $0.50 at time of writing.

```bash
cd ../kubernetes-deployment
terraform destroy

cd ../eks-cluster
terraform destroy
```


## Optionally use the K8s cluster as normal with the CLI
After setting up the cluster, it is possible to interact directly with it using the kubectl CLI

The requirement is to get the KUBECONFIG file created by the terraform apply.

```bash
# Get KUBECONFIG
cd eks-cluster
AWS_KUBECONFIG=$(terraform output -raw kubeconfig_file)

# SET KUBECONFIG
export KUBECONFIG=${AWS_KUBECONFIG}
```

Note - alternatively you could use the AWS CLI to set your kubeconfig using `aws eks update-kubeconfig --name $(terraform output -raw cluster_name)`. 

You can then interact with kubernetes via the CLI 

```bash
# Run Medcat service
helm install my-medcat oci://registry-1.docker.io/cogstacksystems/medcat-service-helm --wait --timeout 10m0s

# Create the ingress
kubectl apply -f resources/ingress-medcat-service.yaml
# Find public url
kubectl get ingress
```