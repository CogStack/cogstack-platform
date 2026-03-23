# MedCAT Service Helm Chart

A Helm chart to deploy CogStack medcat-service

## Installation

```sh
helm install medcat-service-helm oci://registry-1.docker.io/cogstacksystems/medcat-service-helm
```

## Usage
For local testing, by default you can port forward the service using this command:

```sh
kubectl port-forward svc/medcat-service-helm 5000:5000
```

Then navigate to http://localhost:5000 to try the service. You can also use http://localhost:5000/docs to view the REST APIs

## Configuration

To configure medcat service, create a values.yaml file and install with helm.

### Model Pack
You should specify a model pack to be used by the service. By default it will use a small bundled model, which can be used for testing

---
#### Default: Use the demo model pack

There is a model pack already bundled into medcat service, and is the default in this chart.

This pack is only really used for testing, and has just a few concepts built in.

####  Recommended: Download Model on Startup

Enable MedCAT to download the model from a remote URL on container startup.

Create a values file like `values-model-download.yaml` and set these values:
```yaml
model:
  downloadUrl: "http://localhost:9000/models/my-model.zip"
  name: my-model.zip
```

Use this if you prefer dynamic loading of models at runtime.

#### Advanced: Create a custom volume and load a model into it

The service can use a model pack if you want to setup your own download flow. For example, setup an initContainer pattern that downloads to a volume, then mount the volume yourself.

1. Create a persistent volume and PVC in kubernetes following the official documentation. Alternatively specifiy it in `values.extraManifests` and it will be created.

2. Create a values file like the following, which mounts the volume, and defines a custom init container.

```yaml
env:
  APP_MEDCAT_MODEL_PACK: "/my/models/custom-model.zip"
volumeMounts:
  name: model-volume
  mountPath: /my/models

volumes:
- name: model-volume
  persistentVolumeClaim:
    claimName: my-custom-pvc
extraInitContainers:
 - name: model-downloader
   image: busybox:1.28
   # In this command, you can write custom code required to download a file. For example you could configure authentication.
   command: ["sh", "-c", "wget -O /my/models/custom-model.zip http://example.com"]
   volumeMounts:
    - name: model-volume
      mountPath: /my/models

```

### DeID Mode

The service can perform DeID of EHRs by swithcing to the following values

```
env:
  APP_MEDCAT_MODEL_PACK: "/cat/models/examples/example-deid-model-pack.zip"
  DEID_MODE: "true"
  DEID_REDACT: "true"
```

### GPU Support

To run MedCAT Service with GPU acceleration, use the GPU-enabled image and set the pod runtime class accordingly.

Note GPU support is only used for deidentification

Create a values file like `values-gpu.yaml` with the following content:

```yaml
image:
  repository: ghcr.io/cogstack/medcat-service-gpu

runtimeClassName: nvidia

resources:
  limits:
      nvidia.com/gpu: 1
env:
  APP_CUDA_DEVICE_COUNT: 1
  APP_TORCH_THREADS: -1
  DEID_MODE: true
```

> To use GPU acceleration, your Kubernetes cluster should be configured with the NVIDIA GPU Operator or the following components:
> - [NVIDIA device plugin for Kubernetes](https://github.com/NVIDIA/k8s-device-plugin)
> - [NVIDIA GPU Feature Discovery](https://github.com/NVIDIA/gpu-feature-discovery)
> - The [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/)

#### Test GPU support
You can verify that the MedCAT Service pod has access to the GPU by executing `nvidia-smi` inside the pod.

```sh
kubectl exec -it <POD_NAME> -- nvidia-smi
```

You should see the NVIDIA GPU device listing if the GPU is properly accessible.

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` |  |
| autoscaling.enabled | bool | `false` |  |
| autoscaling.maxReplicas | int | `100` |  |
| autoscaling.minReplicas | int | `1` |  |
| autoscaling.targetCPUUtilizationPercentage | int | `80` |  |
| env.APP_ENABLE_DEMO_UI | bool | `true` |  |
| env.APP_ENABLE_METRICS | bool | `false` | Observability Env Vars |
| env.APP_ENABLE_TRACING | bool | `false` |  |
| env.APP_MEDCAT_MODEL_PACK | string | `"/cat/models/examples/example-medcat-v2-model-pack.zip"` | This defines the Model Pack used by the medcat service Example (download on startup): uncomment `ENABLE_MODEL_DOWNLOAD` and the `MODEL_*` URLs below. Example (DeID mode): uncomment `DEID_MODE`/`DEID_REDACT` and use the DeID model pack referenced below. |
| env.OTEL_EXPERIMENTAL_RESOURCE_DETECTORS | string | `"containerid,os"` |  |
| env.OTEL_EXPORTER_OTLP_ENDPOINT | string | `"http://<unused>:4317"` |  |
| env.OTEL_EXPORTER_OTLP_PROTOCOL | string | `"grpc"` |  |
| env.OTEL_LOGS_EXPORTER | string | `"none"` |  |
| env.OTEL_METRICS_EXPORTER | string | `"none"` |  |
| env.OTEL_PYTHON_FASTAPI_EXCLUDED_URLS | string | `"/api/health,/metrics"` |  |
| env.OTEL_RESOURCE_ATTRIBUTES | string | `"k8s.pod.uid=$(K8S_POD_UID),k8s.pod.name=$(K8S_POD_NAME),k8s.namespace.name=$(K8S_POD_NAMESPACE),k8s.node.name=$(K8S_NODE_NAME)"` |  |
| env.OTEL_SERVICE_NAME | string | `"medcat-service"` |  |
| env.OTEL_TRACES_EXPORTER | string | `"otlp"` |  |
| env.SERVER_GUNICORN_MAX_REQUESTS | string | `"100000"` | Set SERVER_GUNICORN_MAX_REQUESTS to a high number instead of the default 1000. Trust k8s instead to restart pod when needed. Example (tuning): see the commented `SERVER_GUNICORN_EXTRA_ARGS` setting below. |
| envValueFrom | object | `{"K8S_NODE_NAME":{"fieldRef":{"fieldPath":"spec.nodeName"}},"K8S_POD_NAME":{"fieldRef":{"fieldPath":"metadata.name"}},"K8S_POD_NAMESPACE":{"fieldRef":{"fieldPath":"metadata.namespace"}},"K8S_POD_UID":{"fieldRef":{"fieldPath":"metadata.uid"}}}` | Allow setting env values from field/configmap/secret references. Defaults to include k8s details for observability. |
| extraInitContainers | list | `[]` | Additional init containers to run before the main container. Can be templated |
| extraManifests | list | `[]` | Additional manifests to deploy to kubernetes. Can be templated |
| fullnameOverride | string | `""` |  |
| hostAliases | list | `[]` | Host aliases for the pod |
| image | object | `{"pullPolicy":"IfNotPresent","repository":"cogstacksystems/medcat-service"}` | This sets the container image more information can be found here: https://kubernetes.io/docs/concepts/containers/images/ |
| image.pullPolicy | string | `"IfNotPresent"` | This sets the pull policy for images. |
| image.repository | string | `"cogstacksystems/medcat-service"` | Image repository for the MedCAT service container |
| imagePullSecrets | list | `[]` | This is for the secrets for pulling an image from a private repository more information can be found here: https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/ |
| ingress.annotations | object | `{}` |  |
| ingress.className | string | `""` |  |
| ingress.enabled | bool | `false` |  |
| ingress.hosts[0].host | string | `"chart-example.local"` |  |
| ingress.hosts[0].paths[0].path | string | `"/"` |  |
| ingress.hosts[0].paths[0].pathType | string | `"ImplementationSpecific"` |  |
| ingress.tls | list | `[]` |  |
| livenessProbe.httpGet.path | string | `"/api/health/live"` |  |
| livenessProbe.httpGet.port | string | `"http"` |  |
| model | object | `{}` | Enable downloading of public models using wget on startup. Model will be downloaded to /models/<name> and used for APP_MEDCAT_MODEL_PACK Example: uncomment `model.downloadUrl` and `model.name` below to fetch a model pack at startup. |
| nameOverride | string | `""` | This is to override the chart name. |
| networkPolicy.egress.egressRules | list | `[]` | Append any custom egress rules following the standard format |
| networkPolicy.egress.enabled | bool | `false` | Choose to block egress by enabling it in the network policy |
| networkPolicy.enabled | bool | `true` | Choose to create a default network policy blocking all ingress other than to the service port. |
| nodeSelector | object | `{}` |  |
| podAnnotations | object | `{}` | This is for setting Kubernetes Annotations to a Pod. For more information checkout: https://kubernetes.io/docs/concepts/overview/working-with-objects/annotations/ |
| podLabels | object | `{}` | This is for setting Kubernetes Labels to a Pod. For more information checkout: https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/ |
| podSecurityContext | object | `{}` |  |
| readinessProbe.httpGet.path | string | `"/api/health/ready"` |  |
| readinessProbe.httpGet.port | string | `"http"` |  |
| replicaCount | int | `1` | This will set the replicaset count more information can be found here: https://kubernetes.io/docs/concepts/workloads/controllers/replicaset/ |
| resources | object | `{}` |  |
| runtimeClassName | string | `""` | Runtime class name for the pod (e.g., "nvidia" for GPU workloads) More information: https://kubernetes.io/docs/concepts/containers/runtime-class/ |
| securityContext | object | `{}` |  |
| service.port | int | `5000` | This sets the ports more information can be found here: https://kubernetes.io/docs/concepts/services-networking/service/#field-spec-ports |
| service.type | string | `"ClusterIP"` | This sets the service type more information can be found here: https://kubernetes.io/docs/concepts/services-networking/service/#publishing-services-service-types |
| serviceAccount.annotations | object | `{}` | Annotations to add to the service account |
| serviceAccount.automount | bool | `true` | Automatically mount a ServiceAccount's API credentials? |
| serviceAccount.create | bool | `true` | Specifies whether a service account should be created |
| serviceAccount.name | string | `""` | The name of the service account to use. If not set and create is true, a name is generated using the fullname template |
| startupProbe.failureThreshold | int | `30` |  |
| startupProbe.httpGet.path | string | `"/api/health/ready"` |  |
| startupProbe.httpGet.port | string | `"http"` |  |
| startupProbe.initialDelaySeconds | int | `2` |  |
| startupProbe.periodSeconds | int | `10` |  |
| tolerations | list | `[]` |  |
| updateStrategy.type | string | `"RollingUpdate"` | Used for Kubernetes deployment .spec.strategy.type. Allowed values are "Recreate" or "RollingUpdate". |
| volumeMounts | list | `[]` | Additional volumeMounts on the output Deployment definition. |
| volumes | list | `[]` | Additional volumes on the output Deployment definition. |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)