# CogStack Community Edition (CogStack CE)

CogStack Community Edition (CogStack CE) is a collection of the open source apps, AI products and data engineering tools in cogstack.

CogStack CE aims to show what is possible with the open source CogStack products, and give you ideas of how you could build upon this and integrate with your real data.

It is installed with a one line command, and comes preconfigured with default data sets, configurations, and example dashboards already setup for you. It is built to run in Kubernetes, from local instances using Minikube, and scale up to production clusters and managed cloud environments.

## What is included in CogStack CE?

It combines model serving, de-identification, model training, notebook-based analysis, and search tooling into one Helm release.

| Product | Primary use case |
| --- | --- |
| MedCAT service | Extract medical concepts and entities from free text. |
| AnonCAT service | De-identify clinical text for safer downstream use. |
| MedCAT Trainer | Train, tune, and manage MedCAT models. |
| JupyterHub | Run notebooks for experimentation and end-to-end workflows. |
| OpenSearch + Dashboards | Index, search, and explore operational or NLP data. |

## Where to start

1. [Tutorial: Quickstart](./tutorial/quickstart-installation.md)
2. [Tutorial: End To End Tutorial](./tutorial/end-to-end-jupyterhub.md)

## Installation and customization (reference)

For the full installation reference, deployment instructions, and customizations, see:

- [Deployment](../platform/deployment/_index.md)
- [CogStack CE Helm chart (install + customization)](../platform/deployment/helm/charts/cogstack-ce-helm.md)

## Models
The default installation comes with basic models that are just for demo purposes. 

There are public models available, that will require a NIH profile or UMLS license. See [MedCAT](https://github.com/CogStack/cogstack-nlp/tree/main/medcat-v2) documentation for how to get these models.

!!! tip
    For access to high performing models trained on real world clinical datasets, contact us

## Next Steps
After setting up and trying CogStack Community edition, you can look into the details and wider tools in the platform

- [Getting Started with CogStack Platform](../overview/getting-started.md)