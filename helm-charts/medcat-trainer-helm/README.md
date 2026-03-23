# MedCAT Trainer Helm Chart

This Helm chart deploys MedCAT Trainer and infrastructure to a Kubernetes cluster.

By default the chart will:

- Run MedCAT Trainer Django server
- Run NGINX for static site hosting and routing
- Run a SOLR and Zookeeper cluster for the Concept DB
- Run a Postgres database for persistence

## Installation

```sh
helm install my-medcat-trainer oci://registry-1.docker.io/cogstacksystems/medcat-trainer-helm
```

## Configuration

See these values for common configurations to change:

| Setting                    | description                                                                                                                                   |
| -------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| `env`                      | Environment variables as defined in the [MedCAT Trainer docs](https://docs.cogstack.org/projects/medcat-trainer/en/latest/installation.html). |
| `medcatConfig`             | MedCAT config file as described [here](https://github.com/CogStack/cogstack-nlp/blob/main/medcat-v2/medcat/config/config.py)                  |
| `env.CSRF_TRUSTED_ORIGINS` | The Host and Port to access the application on                                                                                                |

### Use Sqlite instead of Postgres

Sqlite can be used for smaller single instance deployments

Set these values:

```yaml
DB_ENGINE: "sqlite3"

postgresql:
  enabled: false
```

## Missing features

These features are not yet existing but to be added in future:

- Use a pre existing postgres db
- Use a pre existing SOLR instance
- Migrate from supervisord to standalone deployment for background tasks for better scaling
- Support SOLR authentication from medcat trainer
- Support passing DB OPTIONS to medcat trainer for use in cloud environments

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| oci://registry-1.docker.io/bitnamicharts | postgresql | 16.7.27 |
| oci://registry-1.docker.io/bitnamicharts | solr | 9.6.10 |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` |  |
| autoscaling.enabled | bool | `false` |  |
| autoscaling.maxReplicas | int | `100` |  |
| autoscaling.minReplicas | int | `1` |  |
| autoscaling.targetCPUUtilizationPercentage | int | `80` |  |
| env | object | `{"CSRF_TRUSTED_ORIGINS":"http://localhost:8080","DB_ENGINE":"postgresql","DB_PORT":"5432","DEBUG":"1","EMAIL_HOST":"mail.cogstack.org","EMAIL_PASS":"to-be-changed","EMAIL_PORT":"465","EMAIL_USER":"example@cogstack.org","ENV":"non-prod","LOAD_NUM_DOC_PAGES":"10","MAX_DATASET_SIZE":"10000","MAX_MEDCAT_MODELS":"2","OPENBLAS_NUM_THREADS":"1","RESUBMIT_ALL_ON_STARTUP":"0","UNIQUE_DOC_NAMES_IN_DATASETS":"True","VITE_USE_OIDC":"0"}` | Add any environment variables here that should be set in the medcat-trainer container |
| env.CSRF_TRUSTED_ORIGINS | string | `"http://localhost:8080"` | This sets the CSRF trusted origins for the medcat-trainer container. Change to allow access from other domains |
| envValueFrom | object | `{"K8S_NODE_NAME":{"fieldRef":{"fieldPath":"spec.nodeName"}},"K8S_POD_NAME":{"fieldRef":{"fieldPath":"metadata.name"}},"K8S_POD_NAMESPACE":{"fieldRef":{"fieldPath":"metadata.namespace"}},"K8S_POD_UID":{"fieldRef":{"fieldPath":"metadata.uid"}}}` | Allow setting env values from field/configmap/secret references @default  -- Adds K8s downward API values for tracing |
| fullnameOverride | string | `""` |  |
| hostAliases | list | `[]` | Host aliases for the pod |
| image.pullPolicy | string | `"IfNotPresent"` | This sets the pull policy for images. |
| image.repository | string | `"cogstacksystems/medcat-trainer"` | Image repository for the MedCAT service container |
| imagePullSecrets | list | `[]` | This is for the secrets for pulling an image from a private repository more information can be found here: https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/ |
| ingress.annotations | object | `{}` |  |
| ingress.className | string | `""` |  |
| ingress.enabled | bool | `false` |  |
| ingress.hosts[0].host | string | `"chart-example.local"` |  |
| ingress.hosts[0].paths[0].path | string | `"/"` |  |
| ingress.hosts[0].paths[0].pathType | string | `"ImplementationSpecific"` |  |
| ingress.tls | list | `[]` |  |
| livenessProbe.failureThreshold | int | `30` |  |
| livenessProbe.httpGet.path | string | `"/api/health/live/?format=json"` |  |
| livenessProbe.httpGet.port | string | `"api"` |  |
| medcatConfig | string | Default config for MedCAT Trainer | MedCAT config as described here: [MedCAT config](https://github.com/CogStack/cogstack-nlp/blob/main/medcat-v2/medcat/config/config.py) |
| nameOverride | string | `""` | This is to override the chart name. |
| nginx.livenessProbe.httpGet.path | string | `"/nginx/health/live"` |  |
| nginx.livenessProbe.httpGet.port | string | `"http"` |  |
| nginx.readinessProbe.httpGet.path | string | `"/nginx/health/live"` |  |
| nginx.readinessProbe.httpGet.port | string | `"http"` |  |
| nginxImage | object | `{"pullPolicy":"IfNotPresent","repository":"nginx","tag":"1.29.1"}` | This sets the container image for the nginx server more information can be found here: https://kubernetes.io/docs/concepts/containers/images/ |
| nginxImage.pullPolicy | string | `"IfNotPresent"` | This sets the pull policy for images. |
| nginxImage.repository | string | `"nginx"` | Image repository for the nginx server |
| nginxImage.tag | string | `"1.29.1"` | This sets the image tag for the nginx server |
| nginxUpdateStrategy.type | string | `"RollingUpdate"` |  |
| nodeSelector | object | `{}` |  |
| persistence.media.size | string | `"8Gi"` |  |
| persistence.sqlite.backupDbSize | string | `"300Mi"` |  |
| persistence.sqlite.size | string | `"100Mi"` |  |
| persistence.static.size | string | `"100Mi"` |  |
| persistence.storageClassName | string | `""` |  |
| podAnnotations | object | `{}` | This is for setting Kubernetes Annotations to a Pod. For more information checkout: https://kubernetes.io/docs/concepts/overview/working-with-objects/annotations/ |
| podLabels | object | `{}` | This is for setting Kubernetes Labels to a Pod. For more information checkout: https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/ |
| podSecurityContext | object | `{}` |  |
| postgresql.auth.database | string | `"postgres"` |  |
| postgresql.auth.password | string | `"postgres"` |  |
| postgresql.auth.username | string | `"postgres"` |  |
| postgresql.enabled | bool | `true` |  |
| postgresql.image.repository | string | `"bitnamilegacy/postgresql"` |  |
| postgresql.image.tag | string | `"17.6.0-debian-12-r4"` |  |
| postgresql.primary.persistence.size | string | `"500Mi"` |  |
| provisioning.config | object | Config to load example project from github | Provisioning Config Yaml contents. Can be templated See https://docs.cogstack.org/projects/medcat-trainer/en/latest/provisioning/ |
| provisioning.enabled | bool | `false` | Set to true to enable provisioning of projects and models on startup.. |
| provisioning.existingConfigMap | object | `{}` | Optional: Reference an existing configmap for the provisioning config. |
| readinessProbe.httpGet.path | string | `"/api/health/ready/?format=json"` |  |
| readinessProbe.httpGet.port | string | `"api"` |  |
| replicaCount | int | `1` | This will set the replicaset count more information can be found here: https://kubernetes.io/docs/concepts/workloads/controllers/replicaset/ |
| resources | object | `{}` | Resources for the pod. More information can be found here: https://kubernetes.io/docs/concepts/containers/ Recommendation for a minimal production setup is { requests: { cpu: 2, memory: 2Gi }, limits: { cpu: null <unset>, memory: 4Gi } } |
| runtimeClassName | string | `""` | Runtime class name for the pod (e.g., "nvidia" for GPU workloads) |
| securityContext | object | `{}` |  |
| service.apiPort | int | `8000` |  |
| service.port | int | `8001` | This sets the ports more information can be found here: https://kubernetes.io/docs/concepts/services-networking/service/#field-spec-ports |
| service.type | string | `"ClusterIP"` | This sets the service type more information can be found here: https://kubernetes.io/docs/concepts/services-networking/service/#publishing-services-service-types |
| serviceAccount.annotations | object | `{}` | Annotations to add to the service account |
| serviceAccount.automount | bool | `true` | Automatically mount a ServiceAccount's API credentials? |
| serviceAccount.create | bool | `true` | Specifies whether a service account should be created |
| serviceAccount.name | string | `""` | The name of the service account to use. If not set and create is true, a name is generated using the fullname template |
| solr.auth.enabled | bool | `false` |  |
| solr.collectionReplicas | int | `1` |  |
| solr.collectionShards | int | `1` |  |
| solr.image.repository | string | `"bitnamilegacy/solr"` |  |
| solr.image.tag | string | `"9.9.0-debian-12-r1"` |  |
| solr.persistence.size | string | `"1Gi"` |  |
| solr.podLabels."app.kubernetes.io/component" | string | `"solr"` |  |
| solr.podLabels."app.kubernetes.io/part-of" | string | `"cogstack"` |  |
| solr.replicaCount | int | `1` |  |
| solr.zookeeper.image.repository | string | `"bitnamilegacy/zookeeper"` |  |
| solr.zookeeper.image.tag | string | `"3.9.3-debian-12-r22"` |  |
| solr.zookeeper.persistence.size | string | `"1Gi"` |  |
| solr.zookeeper.replicaCount | int | `1` |  |
| startupProbe.failureThreshold | int | `30` |  |
| startupProbe.httpGet.path | string | `"/api/health/startup/?format=json"` |  |
| startupProbe.httpGet.port | string | `"api"` |  |
| startupProbe.initialDelaySeconds | int | `15` |  |
| startupProbe.periodSeconds | int | `10` |  |
| tolerations | list | `[]` |  |
| tracing.disabledInstrumentations | string | `"psycopg,sqlite3"` |  |
| tracing.experimentalResourceDetectors | string | `"containerid,os"` |  |
| tracing.otlp.enabled | bool | `false` |  |
| tracing.otlp.grpc.enabled | bool | `false` |  |
| tracing.otlp.grpc.endpoint | string | `"http://unused:4317"` |  |
| tracing.otlp.http.enabled | bool | `false` |  |
| tracing.otlp.http.endpoint | string | `"http://unused:4318"` |  |
| tracing.resourceAttributes | object | Adds semantic k8s attributes for tracing | Resource attributes to add to the traces. Can be templated |
| tracing.serviceName | string | `"medcat-trainer"` |  |
| updateStrategy.type | string | `"RollingUpdate"` | Used for Kubernetes deployment .spec.strategy.type. Allowed values are "Recreate" or "RollingUpdate". |
| volumeMounts | list | `[]` | Additional volumeMounts on the output Deployment definition. |
| volumes | list | `[]` | Additional volumes on the output Deployment definition. |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
