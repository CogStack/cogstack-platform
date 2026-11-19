# Openstack Docker Deployment

This Terraform example provides one stop approach to deploy the **CogStack** platform with its core components and observability stack in an OpenStack environment. It is specifically designed to simplify and automate the provisioning and configuration needed to run CogStack reliably and securely. 

This example:

- **Provisions Ubuntu VMs** in openstack
- **Installs Docker and Portainer** on the VMs using Cloud-Init to manage containers easily
- **Uses Ansible for Configuration Management** to deploy necessary CogStack configuration files and system setup
- **Deploys the MedCAT Service** enabling natural language processing on an API
- **Sets up Observability Tools** by deploying Prometheus for metrics collection and Grafana dashboards for monitoring the health and performance of CogStack services.
- **Runs Integration Tests** after the infrastructure is created, asserting that services are running on the created IP addresses.

## Usage

### Requirements
- Terraform - [Install Terraform](https://developer.hashicorp.com/terraform/install)
- Openstack Cloud environment

### 1. Add Required Secrets for your env

Create a `terraform.tfvars` file, based on `terraform.tfvars.example`, containing the secrets for your environment. 

### 2. Run Terraform

Terraform is run on two modules, so we will run one terraform apply in one folder, then another terraform apply in a second folder. This split is needed to solve dependency ordering with terraform providers. 

```bash
# Create VMs in openstack
cd openstack-vms
terraform init
terraform apply --auto-approve

# Export the created values as environment variables, for usage as terraform variables
OPENSTACK_HOSTS=$(terraform output -json created_hosts)
PORTAINER_INSTANCE=$(terraform output -json portainer_instance)
SSH_PRIVATE_KEY=$(terraform output -json ssh_keys | jq -r .private_key_file)

export TF_VAR_portainer_instance=$PORTAINER_INSTANCE
export TF_VAR_hosts=$OPENSTACK_HOSTS
export TF_VAR_ssh_private_key_file=$SSH_PRIVATE_KEY

# Deploy services using docker and portainer 
cd ../docker-deployment
terraform init
terraform apply --auto-approve
```

Initial provisioning takes up to 10 minutes, where time is mostly downloading large docker images

### 3. Accessing the CogStack Platform

Once the deployment is complete and all services are running, you can access the CogStack platform and its components using the following URLs:

```bash
terraform output 
```

```hcl
created_services = {
  "service_urls" = {
    "grafana" = "http://10.0.0.1/grafana"
    "medcat_service" = "http://10.0.0.1:5000"
    "prometheus" = "http://10.0.0.1/prometheus"
  }
}
```

