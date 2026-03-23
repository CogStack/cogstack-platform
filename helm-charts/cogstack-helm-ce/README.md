# CogStack Helm Community Edition

This is a all in one helm chart that runs CogStack on Kubernetes

## Overview

This chart is an umbrella chart that deploys:

| Component        | Description |
|------------------|-------------|
| **MedCAT**       | Medical Concept Annotation Tool — NER and linking for clinical text. |
| **AnonCAT**      | De-identification service (MedCAT in DEID mode) for anonymising text. |
| **MedCAT Trainer** | Training and model management for MedCAT, with Solr and PostgreSQL. |

## Prerequisites

- Kubernetes cluster
- Helm 3+

## Installation

```sh
helm install cogstack oci://registry-1.docker.io/cogstacksystems/cogstack-helm-ce
```

## Configuration
These are some values that are likely to need customization for your deployment:

| Value | Default | Description |
|-------|---------|-------------|
| `medcat-service.replicasCount` | `1` | Number of MedCAT service replicas. |
| `anoncat-service.replicasCount` | `1` | Number of AnonCAT service replicas. |
| `anoncat-service.env.DEID_REDACT` | `false` | Redaction behaviour for de-identification. |
| `medcat-trainer.env.CSRF_TRUSTED_ORIGINS` | `"http://localhost:8080"` | CSRF trusted origins for MedCAT Trainer frontend (set correct value for your deployment, this default works for port forwarding). |

Subcharts (MedCAT service, AnonCAT service, MedCAT Trainer) support additional options; see their respective charts under `../medcat-service-helm` and `../medcat-trainer-helm`. Pass them under the same keys as in this chart’s `values.yaml` (e.g. `medcat-service.*`, `anoncat-service.*`, `medcat-trainer-helm.*`).

Example override file:

```yaml
# my-values.yaml
medcat-service:
  replicasCount: 2
anoncat-service:
  replicasCount: 1
  env:
    APP_ENABLE_DEMO_UI: true
    DEID_MODE: true
```

Install with overrides:

```bash
helm install cogstack . -f my-values.yaml --namespace cogstack --create-namespace
```

## Dependencies

The chart uses local subcharts via relative paths:

- `medcat-service-helm` (as `medcat-service` and `anoncat-service`)
- `medcat-trainer-helm`

## Uninstall

```bash
helm uninstall cogstack-ce --namespace cogstack
```

If the namespace was created only for this release, remove it with:

```bash
kubectl delete namespace cogstack
```

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| file://../medcat-service-helm | medcat-service(medcat-service-helm) | 0.0.1 |
| file://../medcat-service-helm | anoncat-service(medcat-service-helm) | 0.0.1 |
| file://../medcat-trainer-helm | medcat-trainer(medcat-trainer-helm) | 0.0.1 |
| file://charts/jupyterhub | cogstack-jupyterhub | 0.1.0 |
| https://opensearch-project.github.io/helm-charts/ | opensearch | 3.5.0 |
| https://opensearch-project.github.io/helm-charts/ | opensearch-dashboards | 3.5.0 |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| anoncat-service.enabled | bool | `true` | Enable AnonCAT service deployment. |
| anoncat-service.env.APP_MEDCAT_MODEL_PACK | string | `"/cat/models/examples/example-deid-model-pack.zip"` | Model pack used by the MedCAT service when running in DeID mode. |
| anoncat-service.env.DEID_MODE | bool | `true` | Enable DeID mode. |
| anoncat-service.env.DEID_REDACT | bool | `false` | Enable redaction behaviour for DeID. |
| anoncat-service.image.repository | string | `"cogstacksystems/medcat-service"` | MedCAT service image repository for AnonCAT. |
| anoncat-service.image.tag | string | `"1.2.0"` | MedCAT service image tag used by AnonCAT. |
| anoncat-service.replicasCount | int | `1` | Number of AnonCAT (medcat-service in DeID mode) replicas. |
| cogstack-jupyterhub.enabled | bool | `true` | Enable JupyterHub (with hub and singleuser components). |
| cogstack-jupyterhub.jupyterhub.hub.config.Authenticator.admin_users | list | `["admin"]` | Allowed admin users for the dummy authenticator. |
| cogstack-jupyterhub.jupyterhub.hub.config.Authenticator.admin_users[0] | string | `"admin"` | Admin user entry for the dummy authenticator. |
| cogstack-jupyterhub.jupyterhub.hub.config.DummyAuthenticator.password | string | `"SuperSecret"` | Password for the dummy authenticator (do not use in production). |
| cogstack-jupyterhub.jupyterhub.hub.config.JupyterHub.authenticator_class | string | `"dummy"` | Authenticator class used by JupyterHub (dummy authenticator for demo/non-prod). |
| cogstack-jupyterhub.jupyterhub.hub.image.name | string | `"cogstacksystems/jupyter-hub"` | JupyterHub hub image name. |
| cogstack-jupyterhub.jupyterhub.hub.image.tag | string | `"2.2.2"` | JupyterHub hub image tag. |
| cogstack-jupyterhub.jupyterhub.singleuser.image.name | string | `"cogstacksystems/jupyter-singleuser"` | JupyterHub singleuser image name. |
| cogstack-jupyterhub.jupyterhub.singleuser.image.pullPolicy | string | `"IfNotPresent"` | JupyterHub singleuser image pull policy. |
| cogstack-jupyterhub.jupyterhub.singleuser.image.tag | string | `"2.2.2"` | JupyterHub singleuser image tag. |
| fullnameOverride | string | `""` | Fully override the chart fullname. |
| imagePullSecrets | list | `[]` | This is for the secrets for pulling an image from a private repository more information can be found here: https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/ |
| medcat-service.enabled | bool | `true` | Enable MedCAT service deployment. |
| medcat-service.image.repository | string | `"cogstacksystems/medcat-service"` | MedCAT service image repository. |
| medcat-service.image.tag | string | `"1.2.0"` | MedCAT service image tag. |
| medcat-service.replicasCount | int | `1` | Number of MedCAT service replicas. |
| medcat-trainer.enabled | bool | `true` | Enable MedCAT Trainer deployment. |
| medcat-trainer.env.CSRF_TRUSTED_ORIGINS | string | `"http://localhost:8080"` | CSRF trusted origins for the MedCAT Trainer frontend (set for your deployment/port-forward). |
| medcat-trainer.image.tag | string | `"latest@sha256:103215a7540ad614c32866f4cb00ddd91e7aff37cea9abc25dc226c577f9506d"` | MedCAT Trainer image tag (can be a digest-pinned tag). |
| medcat-trainer.provisioning.enabled | bool | `true` | Enable provisioning of projects and models on startup. |
| medcat-trainer.provisioning.existingConfigMap.name | string | `"cogstack-helm-ce-example-trainer-provisioining"` | Existing ConfigMap name containing the provisioning configuration. |
| nameOverride | string | `""` | This is to override the chart name. |
| opensearch-dashboards.enabled | bool | `true` | Deploy an opensearch-dashboards instance |
| opensearch.enabled | bool | `true` | Deploy an opensearch cluster |
| opensearch.extraEnvs | list | Sets the initial admin password for OpenSearch | Extra environment variables to pass to OpenSearch. |
| provisioning.enabled | bool | `true` | Enable provisioning for supporting services (e.g. OpenSearch templates/documents). |
| provisioning.opensearch.createExampleDocuments | bool | `true` | Create example documents in OpenSearch on startup. |
| provisioning.opensearch.createIndexTemplate | bool | `true` | Create the OpenSearch index template on startup. |
| provisioning.opensearchDashboards.createDashboards | bool | `true` | Create dashboards on startup. |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)