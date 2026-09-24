# ocr-service Helm Chart

A Helm chart to deploy CogStack OCR Service

**Homepage:** <https://docs.cogstack.org/>

## Installation

```sh
helm install ocr-service oci://registry-1.docker.io/cogstacksystems/ocr-service-helm
```

## Usage
For local testing, by default you can port forward the service using this command:

```sh
kubectl port-forward svc/ocr-service 8090:8090
```

Then navigate to http://localhost:8090 to try the service. You can also use http://localhost:8090/docs to view the REST APIs

## Configuration

To configure the service, create a values.yaml file and install with helm.

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` |  |
| autoscaling.enabled | bool | `false` |  |
| autoscaling.maxReplicas | int | `100` |  |
| autoscaling.minReplicas | int | `1` |  |
| autoscaling.targetCPUUtilizationPercentage | int | `80` |  |
| env.OCR_SERVICE_CONVERTER_THREADS | string | `"1"` |  |
| env.OCR_SERVICE_CPU_THREADS | string | `"1"` |  |
| env.OCR_SERVICE_DEBUG_MODE | string | `"false"` |  |
| env.OCR_SERVICE_GUNICORN_GRACEFUL_TIMEOUT | string | `"30"` |  |
| env.OCR_SERVICE_GUNICORN_LOG_FILE_PATH | string | `"-"` |  |
| env.OCR_SERVICE_GUNICORN_LOG_LEVEL | string | `"info"` |  |
| env.OCR_SERVICE_GUNICORN_MAX_REQUESTS | string | `"50000"` |  |
| env.OCR_SERVICE_GUNICORN_MAX_REQUESTS_JITTER | string | `"5000"` |  |
| env.OCR_SERVICE_GUNICORN_TIMEOUT | string | `"300"` |  |
| env.OCR_SERVICE_HOST | string | `"0.0.0.0"` |  |
| env.OCR_SERVICE_IMAGE_DPI | string | `"200"` |  |
| env.OCR_SERVICE_LIBRE_OFFICE_PROCESS_TIMEOUT | string | `"20"` |  |
| env.OCR_SERVICE_LOG_LEVEL | string | `"20"` |  |
| env.OCR_SERVICE_OPERATION_MODE | string | `"OCR"` |  |
| env.OCR_SERVICE_PORT | string | `"8090"` |  |
| env.OCR_SERVICE_TESSERACT_CUSTOM_CONFIG_FLAGS | string | `""` |  |
| env.OCR_SERVICE_TESSERACT_LANG | string | `"eng"` |  |
| env.OCR_SERVICE_TESSERACT_NICE | string | `"-18"` |  |
| env.OCR_SERVICE_TESSERACT_TIMEOUT | string | `"30"` |  |
| env.OCR_SERVICE_WORKER_CLASS | string | `"sync"` |  |
| env.OCR_TMP_DIR | string | `"/ocr_service/tmp"` |  |
| env.OCR_WEB_SERVICE_WORKERS | string | `"1"` |  |
| envValueFrom | object | `{"K8S_NODE_NAME":{"fieldRef":{"fieldPath":"spec.nodeName"}},"K8S_POD_NAME":{"fieldRef":{"fieldPath":"metadata.name"}},"K8S_POD_NAMESPACE":{"fieldRef":{"fieldPath":"metadata.namespace"}},"K8S_POD_UID":{"fieldRef":{"fieldPath":"metadata.uid"}}}` | Allow setting env values from field/configmap/secret references. Defaults to include k8s details for observability. |
| extraInitContainers | list | `[]` | Additional init containers to run before the main container. Can be templated |
| extraManifests | list | `[]` | Additional manifests to deploy to kubernetes. Can be templated |
| fullnameOverride | string | `""` |  |
| hostAliases | list | `[]` | Host aliases for the pod |
| httpRoute | object | `{"annotations":{},"enabled":false,"hostnames":["chart-example.local"],"parentRefs":[{"name":"gateway","sectionName":"http"}],"rules":[{"matches":[{"path":{"type":"PathPrefix","value":"/headers"}}]}]}` | Expose the service via gateway-api HTTPRoute Requires Gateway API resources and suitable controller installed within the cluster (see: https://gateway-api.sigs.k8s.io/guides/) |
| image | object | `{"pullPolicy":"IfNotPresent","repository":"cogstacksystems/cogstack-ocr-service"}` | This sets the container image more information can be found here: https://kubernetes.io/docs/concepts/containers/images/ |
| image.pullPolicy | string | `"IfNotPresent"` | This sets the pull policy for images. |
| image.repository | string | `"cogstacksystems/cogstack-ocr-service"` | Image repository for the MedCAT service container |
| imagePullSecrets | list | `[]` | This is for the secrets for pulling an image from a private repository more information can be found here: https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/ |
| ingress.annotations | object | `{}` |  |
| ingress.className | string | `""` |  |
| ingress.enabled | bool | `false` |  |
| ingress.hosts[0].host | string | `"chart-example.local"` |  |
| ingress.hosts[0].paths[0].path | string | `"/"` |  |
| ingress.hosts[0].paths[0].pathType | string | `"ImplementationSpecific"` |  |
| ingress.tls | list | `[]` |  |
| livenessProbe.failureThreshold | int | `3` |  |
| livenessProbe.httpGet.path | string | `"/api/health"` |  |
| livenessProbe.httpGet.port | string | `"http"` |  |
| livenessProbe.initialDelaySeconds | int | `30` |  |
| livenessProbe.periodSeconds | int | `30` |  |
| livenessProbe.timeoutSeconds | int | `5` |  |
| nameOverride | string | `""` | This is to override the chart name. |
| nodeSelector | object | `{}` |  |
| podAnnotations | object | `{}` | This is for setting Kubernetes Annotations to a Pod. For more information checkout: https://kubernetes.io/docs/concepts/overview/working-with-objects/annotations/ |
| podLabels | object | `{}` | This is for setting Kubernetes Labels to a Pod. For more information checkout: https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/ |
| podSecurityContext.fsGroup | int | `10001` |  |
| podSecurityContext.fsGroupChangePolicy | string | `"OnRootMismatch"` |  |
| readinessProbe.failureThreshold | int | `6` |  |
| readinessProbe.httpGet.path | string | `"/api/ready"` |  |
| readinessProbe.httpGet.port | string | `"http"` |  |
| readinessProbe.initialDelaySeconds | int | `20` |  |
| readinessProbe.periodSeconds | int | `10` |  |
| readinessProbe.timeoutSeconds | int | `5` |  |
| replicaCount | int | `1` | This will set the replicaset count more information can be found here: https://kubernetes.io/docs/concepts/workloads/controllers/replicaset/ |
| resources | object | `{}` | Configure resources for the pod. More information can be found here: https://kubernetes.io/docs/concepts/containers/ Recommendation for a default production model is { requests: { cpu: 500m, memory: 512Mi }, limits: { cpu: null <unset>, memory: 1Gi } } |
| runtimeClassName | string | `""` | Runtime class name for the pod (e.g., "nvidia" for GPU workloads) More information: https://kubernetes.io/docs/concepts/containers/runtime-class/ |
| securityContext.allowPrivilegeEscalation | bool | `false` |  |
| securityContext.capabilities.drop[0] | string | `"ALL"` |  |
| securityContext.readOnlyRootFilesystem | bool | `false` |  |
| securityContext.runAsGroup | int | `10001` |  |
| securityContext.runAsNonRoot | bool | `true` |  |
| securityContext.runAsUser | int | `10001` |  |
| service.port | int | `8090` | This sets the ports more information can be found here: https://kubernetes.io/docs/concepts/services-networking/service/#field-spec-ports |
| service.type | string | `"ClusterIP"` | This sets the service type more information can be found here: https://kubernetes.io/docs/concepts/services-networking/service/#publishing-services-service-types |
| serviceAccount.annotations | object | `{}` | Annotations to add to the service account |
| serviceAccount.automount | bool | `true` | Automatically mount a ServiceAccount's API credentials? |
| serviceAccount.create | bool | `true` | Specifies whether a service account should be created |
| serviceAccount.name | string | `""` | The name of the service account to use. If not set and create is true, a name is generated using the fullname template |
| startupProbe.failureThreshold | int | `90` |  |
| startupProbe.httpGet.path | string | `"/api/ready"` |  |
| startupProbe.httpGet.port | string | `"http"` |  |
| startupProbe.initialDelaySeconds | int | `2` |  |
| startupProbe.periodSeconds | int | `10` |  |
| startupProbe.timeoutSeconds | int | `5` |  |
| tmp.emptyDir.medium | string | `""` |  |
| tmp.emptyDir.sizeLimit | string | `"1Gi"` |  |
| tmp.enabled | bool | `true` |  |
| tmp.mountPath | string | `"/ocr_service/tmp"` |  |
| tolerations | list | `[]` |  |
| updateStrategy.type | string | `"RollingUpdate"` | Used for Kubernetes deployment .spec.strategy.type. Allowed values are "Recreate" or "RollingUpdate". |
| volumeMounts | list | `[]` | Additional volumeMounts on the output Deployment definition. |
| volumes | list | `[]` | Additional volumes on the output Deployment definition. |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)