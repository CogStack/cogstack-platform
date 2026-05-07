# Deployment

## Introduction

!!! warning

    We are actively working on improving the deployment of CogStack

    The following section shows how to run MedCAT Service in a variety of environments and configs.

    To setup a full deployment of CogStack including the data pipelines and infrastructure, contact us

## Overview
CogStack is a self-hosted platform made up of microservices and tools

If you want to get started quickly, check out the [Quickstart](./get-started/quickstart.md) guide to run CogStack locally in just a few simple steps.

Our recommended deployment method is on Kubernetes using Helm charts. This makes installing and managing CogStack easy and consistent. For a detailed walkthrough, see [Helm](./helm/index.md).

You can run Kubernetes anywhere — on your own hardware or through cloud providers like AWS (EKS) or Azure (AKS). To help with this, we provide basic examples using Terraform that will deploy the infrastructure, services, and perform tests using a few terraform commands. These are available in the [Examples](./examples/index.md) section.

Along with kubernetes, it is also possible to run CogStack through docker compose. See the [Docker Compose](./reference/docker-compose/_index.md) section for this. 

## Deployment Recommendations

- Deploy CogStack on Kubernetes for best scalability and reliability.
- Use Helm to install and manage your CogStack instances.
- Manage your infrastructure declaratively with Terraform.
- Keep your Terraform code in your own Git repository and adopt GitOps practices


