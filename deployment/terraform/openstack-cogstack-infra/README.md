
Terraform Module for provisioning VMs on Openstack to be used for Cogstack deployments

## Features
- Create VMs with given names
- Setup VMs to install Docker and run Portainer on startup
- Setup Networking in Openstack to allow communications between expected services

## Requirements
- An Openstack Environment able to create Compute and Networking rules
- Secrets used by the initial portainer setup