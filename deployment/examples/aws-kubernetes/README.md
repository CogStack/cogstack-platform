# AWS EKS Deployment

This is an example deployment of CogStack in AWS. It will create publically accessible services, so is not suitable for production deployment.

The recommended deployment in AWS is based on using Kubernetes through AWS EKS.

This example will create a AWS EKS cluster, setup any necessary config, deploy CogStack to the cluster, and test that it is available.

## Usage
Terraform creates the Kubernetes cluster, then `kubectl` applies the CogStack Community Edition manifests from [`deployment/kubernetes`](https://github.com/CogStack/cogstack-platform/tree/main/deployment/kubernetes).

### Requirements
- Terraform - [Install Terraform](https://developer.hashicorp.com/terraform/install)
- [kubectl](https://kubernetes.io/docs/tasks/tools/) and `envsubst` (part of GNU gettext)
- AWS Credentials for an account that can create and destroy resources. 


### Steps

### 1. Add Required Secrets for your env
This readme uses environment variables for access:

1. See the `.env.example` file for the required details.
2. Create a file `.env` with those fields set for your account. 
3. Execute `source .env` to set those environment variables

If desired, see the official documentation for other ways to provide AWS credentials https://registry.terraform.io/providers/hashicorp/aws/latest/docs#authentication-and-configuration

### 2. Run Terraform
Terraform creates the cluster, then `kubectl` applies the CogStack manifests. The commands below assume this example folder is inside a clone of [cogstack-platform](https://github.com/CogStack/cogstack-platform), so the manifests are at `../../../kubernetes`.

Initial provisioning takes around 15 minutes.

```bash
# Set AWS credentials 
source .env

# Create AWS EKS infra
cd eks-cluster
terraform init
terraform apply --auto-approve

AWS_KUBECONFIG=$(terraform output -raw kubeconfig_file)

# Deploy CogStack with the plain manifests in deployment/kubernetes
export KUBECONFIG=$AWS_KUBECONFIG
export DOMAIN=cogstack.example.org
kubectl kustomize ../../../kubernetes | envsubst '${DOMAIN}' | kubectl apply -f -
kubectl -n cogstack get pods -w
```

### 3. Accessing the CogStack Platform

Once the deployment is complete and all services are running, you can access the CogStack platform and its components.

Use kubernetes port-forwarding to make the services accessible locally:

```bash
kubectl -n cogstack port-forward svc/medcat-service 5000:5000 &
kubectl -n cogstack port-forward svc/anoncat-service 5001:5000 &
kubectl -n cogstack port-forward svc/ocr-service 8090:8090 &
kubectl -n cogstack port-forward svc/medcat-trainer 8001:8001 &
kubectl -n cogstack port-forward svc/opensearch 9200:9200 &
kubectl -n cogstack port-forward svc/opensearch-dashboards 5601:5601 &
kubectl -n cogstack port-forward svc/jupyterhub 8000:8000 &
```

Then visit:

- MedCAT Service: http://127.0.0.1:5000
- AnonCAT: http://127.0.0.1:5001
- OCR Service: http://127.0.0.1:8090
- MedCAT Trainer: http://127.0.0.1:8001
- OpenSearch: https://127.0.0.1:9200 (user `admin`, password `opensearch-312$A`)
- OpenSearch Dashboards: http://127.0.0.1:5601
- JupyterHub: http://127.0.0.1:8000 (any username, password `SuperSecret`), then open http://127.0.0.1:8000/user/admin/notebooks/medcat-service-tutorial.ipynb to get started with a tutorial

### 4. Continue with the CogStack Tutorials

You've now got a fully working deployment of CogStack Community Edition!

Now you can look at the product tour and interactively follow along with this: https://docs.cogstack.org/en/latest/cogstack-ce/product-tour/ .

You've already port-forwarded the services, so you should be able to just open all the URLs and try out the applications.


### Optional - Destroy

You can destroy the infra to save costs when it wont be used for a long time.

Do note that there is an initial cost every time the EKS infrastructure is created, looks to be around $0.50 at time of writing.

```bash
# From the eks-cluster folder, with KUBECONFIG set as above
kubectl delete namespace cogstack
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
# See the CogStack pods
kubectl -n cogstack get pods
```

## Optional - Public Access

You can setup public access over the internet to your deployed services.

One way to do this is to use an AWS ALB. The CogStack manifests include an ingress (`ingress.yaml` in [`deployment/kubernetes`](https://github.com/CogStack/cogstack-platform/tree/main/deployment/kubernetes)) with one host per app under `${DOMAIN}`. Install the [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/) (or enable EKS Auto Mode load balancing), then edit your copy of `ingress.yaml` to use it:

```yaml
metadata:
  name: cogstack
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
spec:
  ingressClassName: alb
```

Re-run the deploy command, then point DNS for the app hosts at the ALB address shown by `kubectl -n cogstack get ingress cogstack`.
