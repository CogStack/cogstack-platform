# Openstack Docker Deployment

<div class="tech-stack-banner" markdown="block">

{{ cogstack_banner_logo() }}

:simple-openstack:{ .tech-icon-openstack } :simple-docker:{ .tech-icon-docker } :simple-portainer: :simple-ansible:{ .tech-icon-ansible } :simple-terraform:{ .tech-icon-terraform }

</div>

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

### 1. Get the configuration files

Get the Terraform files for this example (the ZIP contains all `deployment-examples`; use the `openstack-docker` folder for this guide).

[Download all deployment examples (ZIP)](../../../assets/downloads/deployment-examples.zip){ .md-button }

Alternatively you can view the file contents here:

#### openstack-vms terraform files

This module provisions OpenStack VMs and networking for the stack.

{{ embed_all_files_in_directory_as_snippets('openstack-docker/openstack-vms') }}

#### docker-deployment terraform files

This module deploys Docker-based CogStack services.

{{ embed_all_files_in_directory_as_snippets('openstack-docker/docker-deployment') }}

### 2. Add required secrets for your environment

Create a `terraform.tfvars` file, based on `terraform.tfvars.example`, containing the secrets for your environment.

### 3. Run Terraform

```bash
terraform init
terraform apply
```

Initial provisioning takes up to 10 minutes, where time is mostly downloading large docker images

### 4. Accessing the CogStack Platform

Once the deployment is complete and all services are running, you can access the CogStack platform and its components using the following URLs:

```bash
terraform output service_urls
```

## Troubleshooting


### unsupported protocol scheme
If you make changes to the created VM infrastructure, and want to reapply, you can run into this error

```
│ Error: Get "/api/endpoints/4": unsupported protocol scheme ""
│ 
│   with module.cogstack_docker_services.portainer_environment.portainer_envs["cogstack-devops"],
│   on ../../modules/cogstack-docker-services/environments.tf line 3, in resource "portainer_environment" "portainer_envs":
│    3: resource "portainer_environment" "portainer_envs" {
```

Fix by targetting just the infra module first:

```bash
terraform apply -target=module.openstack_cogstack_infra
terraform apply
```

For details: the error specifically occurs after making a change to the controller host, forcing it to be deleted and recreated, however terraform still uses the IP address in the portainer provider. Targetting just the infra module first, means terraform wont call any APIs during the plan stage using the old IP address.
