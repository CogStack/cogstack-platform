Welcome to the CogStack Documentation site.

## What is CogStack?

CogStack lets you unlock the power of healthcare data.

CogStack is a healthcare suite with interchangeable modules for analysing clinical data using AI to draw insights from text in or documents in an Electronic Health Records.

There are a wide range of features including Generative AI, Natural Language Processing, Full Search, Alerting, Cohort Selection, Population Health Dashboards, Deep Phenotyping and Clinical Research.

CogStack is a commercial open-source product, with the code for the community edition available on GitHub: [https://github.com/CogStack/](https://github.com/CogStack/). For enterprise deployments, full platform setup, and advanced features, please [contact us](https://docs.cogstack.org/en/latest/).

## Quickstart

Deploy the CogStack Community Edition on an existing Kubernetes cluster using helm.

<!-- termynal -->

```sh
$ helm install \
    cogstack oci://registry-1.docker.io/cogstacksystems/cogstack-helm-ce \
    --timeout=15m0s
---> 100%
Pulled: registry-1.docker.io/cogstacksystems/cogstack-helm-ce:0.0.1
Digest: sha256:02e8ad3df7173270f7fdeb3e1ed5133427cec06ffc15b4ce763fa9bb062c8df1

NAME: cogstack
LAST DEPLOYED: Mon Mar 23 16:19:05 2026
NAMESPACE: default
STATUS: deployed
REVISION: 1
DESCRIPTION: Install complete
NOTES:
...
# CogStack Community Edition is installed
# Setup Complete
# Run this command line to setup port-forwarding and access services
# `helm get notes cogstack | bash`
```

See [CogStack Community Edition (CE)](cogstack-ce/_index.md) to continue this process.

## Architecture

![CogStack Architecture](overview/attachments/architecture.png)

CogStack is comprised of a suite of applications, all using a common AI and data engineering platform. It is designed to be a self hosted platform where you run your own instances and keep all of your data on premise, with full support for air gapped environments.

The applications provide features for:

- Clinical Coding
- Search and Audit of EHRs
- Cohorting
- EHR Analytics
- DeIdentification of patient records
- Clinical Decision Support (CDS)

The AI and Data Engineering layer comprises of:

- Healthcare Language Models trained on large data real world data sets
- The open source MedCAT and AnonCAT natural language processing libraries
- Data Engineering pipelines using Apache NiFi and OpenSearch to read unstructured and structured data
- MLOps tooling for model training and validation

!!! tip
    Many of these apps and tools are open source and available on GitHub (subject to the licensing in each project), in the [CogStack GitHub](https://github.com/CogStack).

    The public documentation on this page covers these open source community offerings.

    For advanced features and enterprise level features see our range of [products](https://cogstack.org/products/).

## Next Steps

[Get Started ](overview/getting-started.md){ .md-button .md-button--primary }

## Community and support

- **Questions?** Reach out in the [CogStack community forum](https://discourse.cogstack.org/).
- **Code and projects:** [CogStack on GitHub](https://github.com/orgs/CogStack/repositories).
