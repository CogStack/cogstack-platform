# AWS EKS Deployment

This is an example deployment of CogStack in AWS. It will create publically accessible services, so is not suitable for production deployment.

The recommended deployment in AWS is based on using Kubernetes through AWS EKS.

This example will create a AWS EKS cluster, setup any necessary config, deploy CogStack to the cluster, and test that it is available.

## Usage
Deployment through terraform is carried out through two terraform commands, to handle the sequencing issues between making a k8s cluster and using it in AWS.

### Requirements
- Terraform - [Install Terraform](https://developer.hashicorp.com/terraform/install)
- AWS Credentials for an account that can create and destroy resources. 


### Steps

### 1. Add Required Secrets for your env
This readme uses environment variables for access:

1. See the `.env.example` file for the required details.
2. Create a file `.env` with those fields set for your account. 
3. Execute `source .env` to set those environment variables

If desired, see the official documentation for other ways to provide AWS credentials https://registry.terraform.io/providers/hashicorp/aws/latest/docs#authentication-and-configuration

### 2. Run Terraform
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

You can then interact with kubernetes via the CLI for example:

```bash
# Run Medcat service
helm install medcat-service oci://registry-1.docker.io/cogstacksystems/medcat-service-helm --wait --timeout 10m0s
```

## Optional - Public Access

You can setup public access over the internet to your deployed services.

One way to do this is to use an AWS ALB, along with defining the ingress routes of the helm chart. 

See this terraform code for an example

```hcl
resource "kubernetes_ingress_class" "application_load_balancer" {
  # An Application Load Balancer  is required in order to create public URLs. 
  # The load balancer controller creates instances of the ALB when it sees ingress objects with the right annotations.
  metadata {
    name = "alb"
    labels = {
      "app.kubernetes.io/name" = "LoadBalancerController"
    }
  }
  spec {
    controller = "eks.amazonaws.com/alb"
  }
}

locals {
  services = {
    medcat_service = {
      path_prefix = "medcat-service"
    }
  }
}
module "cogstack_helm_services" {
  depends_on            = [kubernetes_ingress_class.application_load_balancer]
source                = "github.com/CogStack/cogstack-platform-toolkit//deployment/terraform/modules/cogstack-helm-services?ref=terraform-modules-v0.1.0"
  medcat_service_values = <<EOT
ingress:
    annotations:
        alb.ingress.kubernetes.io/scheme: internet-facing
        alb.ingress.kubernetes.io/target-type: ip
        alb.ingress.kubernetes.io/healthcheck-path: /api/health/live
    className: alb
    http:
    - paths:
        - path: /${local.services.medcat_service.path_prefix}
          pathType: Prefix
EOT
}

locals {
  medcat_ingress_address = module.cogstack_helm_services.service_urls.medcat_service.ip_address
}
output "service_urls" {
  value = {
    medcat_service = {
      example_curl = "curl http://${local.medcat_ingress_address}/${local.services.medcat_service.path_prefix}/api/info"
      example_ui   = "http://${local.medcat_ingress_address}/${local.services.medcat_service.path_prefix}/docs"
    }
  }
  description = "Public URls to call services on"
}

```