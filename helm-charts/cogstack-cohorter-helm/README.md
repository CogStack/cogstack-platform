# CogStack Cohorter Helm Chart

CogStack Cohorter — cohort identification powered by Ollama and MedCAT

## Architecture

| Component | Image | Description |
|-----------|-------|-------------|
| **WebApp** | `cogstacksystems/cogstack-cohorter-webapp` | React + Node.js frontend and API |
| **NL2DSL** | `cogstacksystems/cogstack-cohorter-nl2dsl` | Natural language → cohort DSL compiler |
| **MedCAT** | `cogstacksystems/medcat-service` | Clinical NER and concept normalisation (subchart) |
| **Ollama** | `ollama/ollama` | LLM serving backend (subchart) |

MedCAT and Ollama are deployed as **subcharts**:
- MedCAT: [`cogstacksystems/medcat-service-helm`](https://hub.docker.com/r/cogstacksystems/medcat-service-helm) (OCI)
- Ollama: [`otwld/ollama`](https://github.com/otwld/ollama-helm)

## Prerequisites

- Kubernetes 1.21+
- Helm 3.10+
- A storage class that supports `ReadWriteOnce` PVCs
- Sufficient node resources for the Ollama model (the default `gpt-oss:20b` requires ~14 GB of memory/VRAM)

## Installation

From Docker Hub OCI (published chart):

```bash
helm install cogstack-cohorter oci://registry-1.docker.io/cogstacksystems/cogstack-cohorter-helm
```

## Configuration

All configurable values are in [`values.yaml`](./values.yaml). Key sections:

### Ollama

```yaml
ollama:
  enabled: true
  ollama:
    models:
      pull:
        - gpt-oss:20b   # pulled automatically on first startup
  persistentVolume:
    enabled: true
    size: 10Gi
```

Models are pulled automatically by the otwld subchart's built-in init container. Change `ollama.ollama.models.pull` to use a different model — make sure `nl2dsl.env.OLLAMA_MODEL` matches.

### MedCAT

```yaml
medcat:
  enabled: true
  env:
    APP_MEDCAT_MODEL_PACK: "/cat/models/examples/example-medcat-v2-model-pack.zip"
```

To use a custom model pack, provide a download URL:

```yaml
medcat:
  model:
    downloadUrl: "https://your-host/medcat_model_pack.zip"
    name: "medcat_model_pack.zip"
```

### WebApp data volume

The WebApp requires a SNOMED data directory mounted at `/usr/src/app/server/data`. A PVC is provisioned automatically:

```yaml
webapp:
  persistence:
    enabled: true
    size: 5Gi
```

Populate the PVC with either:
- `snomed_terms_data.tar.gz` — auto-extracted by the entrypoint on first startup, or
- Pre-extracted files: `snomed_terms.json`, `cui_pt2ch.json`, and patient data files

To generate synthetic patient data on first startup (demo mode):

```yaml
webapp:
  env:
    RANDOM_DATA: "true"
```

### Ingress

```yaml
ingress:
  enabled: true
  className: nginx
  hosts:
    - host: cohorter.example.com
      paths:
        - path: /
          pathType: ImplementationSpecific
  tls:
    - secretName: cohorter-tls
      hosts:
        - cohorter.example.com
```

### Autoscaling (webapp only)

```yaml
autoscaling:
  enabled: true
  minReplicas: 1
  maxReplicas: 3
  targetCPUUtilizationPercentage: 80
```

## Uninstallation

```bash
helm uninstall cogstack-cohorter
```

## Support

For issues and questions, please visit the [CogStack GitHub repository](https://github.com/CogStack/cogstack-platform).

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| https://otwld.github.io/ollama-helm/ | ollama(ollama) | >=0.1.0 |
| oci://registry-1.docker.io/cogstacksystems | medcat(medcat-service-helm) | 0.0.1 |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| autoscaling | object | `{"enabled":false,"maxReplicas":3,"minReplicas":1,"targetCPUUtilizationPercentage":80}` | ------------------------------------------------------------------------- |
| fullnameOverride | string | `""` |  |
| global | object | `{"imagePullSecrets":[]}` | ------------------------------------------------------------------------- |
| httpRoute | object | `{"annotations":{},"enabled":false,"hostnames":["chart-example.local"],"parentRefs":[{"name":"gateway","sectionName":"http"}],"rules":[{"matches":[{"path":{"type":"PathPrefix","value":"/"}}]}]}` | ------------------------------------------------------------------------- |
| ingress | object | `{"annotations":{},"className":"","enabled":false,"hosts":[{"host":"cogstack-cohort.local","paths":[{"path":"/","pathType":"ImplementationSpecific"}]}],"tls":[]}` | ------------------------------------------------------------------------- |
| medcat | object | `{"enabled":true,"env":{"APP_ENABLE_METRICS":"true","APP_MEDCAT_MODEL_PACK":"/cat/models/examples/example-medcat-v2-model-pack.zip"},"image":{"tag":"latest"},"resources":{},"service":{"port":5000}}` | ------------------------------------------------------------------------- |
| medcat.enabled | bool | `true` | Enable the MedCAT subchart. |
| nameOverride | string | `"cogstack-cohorter"` | ------------------------------------------------------------------------- |
| nl2dsl | object | `{"affinity":{},"enabled":true,"env":{"ALLOW_ORIGINS":"*","OLLAMA_MODEL":"llama3.2:3b"},"image":{"pullPolicy":"Always","repository":"cogstacksystems/cogstack-cohorter-nl2dsl","tag":"latest"},"livenessProbe":{"httpGet":{"path":"/","port":"http"},"initialDelaySeconds":30,"periodSeconds":10},"nodeSelector":{},"readinessProbe":{"httpGet":{"path":"/","port":"http"},"initialDelaySeconds":10,"periodSeconds":5},"replicaCount":1,"resources":{},"service":{"port":3002,"type":"ClusterIP"},"tolerations":[]}` | ------------------------------------------------------------------------- |
| nl2dsl.enabled | bool | `true` | Enable the NL2DSL deployment and service. |
| ollama | object | `{"enabled":true,"ollama":{"models":{"pull":["llama3.2:3b"]}},"persistentVolume":{"enabled":true,"size":"10Gi","storageClass":""},"resources":{},"service":{"port":11434,"type":"ClusterIP"}}` | ------------------------------------------------------------------------- |
| ollama.enabled | bool | `true` | Enable the Ollama subchart. |
| podAnnotations | object | `{}` | ------------------------------------------------------------------------- |
| podLabels | object | `{}` |  |
| podSecurityContext | object | `{}` |  |
| securityContext | object | `{}` |  |
| serviceAccount | object | `{"annotations":{},"automount":true,"create":true,"name":""}` | ------------------------------------------------------------------------- |
| webapp | object | `{"affinity":{},"data":{"downloadUrl":""},"enabled":true,"env":{"RANDOM_DATA":"true"},"image":{"pullPolicy":"Always","repository":"cogstacksystems/cogstack-cohorter-webapp","tag":"latest"},"initContainers":[],"livenessProbe":{"httpGet":{"path":"/","port":"http"},"initialDelaySeconds":60,"periodSeconds":15},"nodeSelector":{},"persistence":{"accessMode":"ReadWriteOnce","enabled":true,"existingClaim":"","size":"5Gi","storageClass":""},"readinessProbe":{"httpGet":{"path":"/","port":"http"},"initialDelaySeconds":30,"periodSeconds":10},"replicaCount":1,"resources":{},"service":{"port":3000,"type":"ClusterIP"},"tolerations":[]}` | ------------------------------------------------------------------------- |
| webapp.enabled | bool | `true` | Enable the WebApp deployment and service. |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
