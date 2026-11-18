
# CogStack Helm Terraform Module
This Terraform module deploys CogStack services using Helm charts on a Kubernetes cluster.

## Example usage

```hcl
module "cogstack_helm_services" {
  source = "path_to_module"
  medcat_service_values = <<EOT
replicaCount: 2
EOT

}
```

## What is this module for?
This module simplifies deploying the CogStack with an opinionated Helm release setup. 

It does the following:
- Deploys MedCAT Service using Helm
- Configures Ingress based on path prefix and hostname
- Runs a terraform Check as an integration test on the deployed service

The module expects Kubernetes and Helm providers to be configured and a working cluster available.



