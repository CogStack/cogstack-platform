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
| autoscaling.enabled | bool | `false` |  |
| autoscaling.maxReplicas | int | `3` |  |
| autoscaling.minReplicas | int | `1` |  |
| autoscaling.targetCPUUtilizationPercentage | int | `80` |  |
| fullnameOverride | string | `""` |  |
| global.imagePullSecrets | list | `[]` |  |
| ingress.annotations | object | `{}` |  |
| ingress.className | string | `""` |  |
| ingress.enabled | bool | `false` |  |
| ingress.hosts[0].host | string | `"cogstack-cohort.local"` |  |
| ingress.hosts[0].paths[0].path | string | `"/"` |  |
| ingress.hosts[0].paths[0].pathType | string | `"ImplementationSpecific"` |  |
| ingress.tls | list | `[]` |  |
| medcat.enabled | bool | `true` |  |
| medcat.env.APP_ENABLE_METRICS | string | `"true"` |  |
| medcat.env.APP_MEDCAT_MODEL_PACK | string | `"/cat/models/examples/example-medcat-v2-model-pack.zip"` |  |
| medcat.image.tag | string | `"latest"` |  |
| medcat.resources | object | `{}` |  |
| medcat.service.port | int | `5000` |  |
| nameOverride | string | `""` |  |
| nl2dsl.affinity | object | `{}` |  |
| nl2dsl.enabled | bool | `true` |  |
| nl2dsl.env.ALLOW_ORIGINS | string | `"*"` |  |
| nl2dsl.env.OLLAMA_MODEL | string | `"gpt-oss:20b"` |  |
| nl2dsl.image.pullPolicy | string | `"IfNotPresent"` |  |
| nl2dsl.image.repository | string | `"cogstacksystems/cogstack-cohorter-nl2dsl"` |  |
| nl2dsl.image.tag | string | `"latest"` |  |
| nl2dsl.livenessProbe.httpGet.path | string | `"/"` |  |
| nl2dsl.livenessProbe.httpGet.port | string | `"http"` |  |
| nl2dsl.livenessProbe.initialDelaySeconds | int | `30` |  |
| nl2dsl.livenessProbe.periodSeconds | int | `10` |  |
| nl2dsl.nodeSelector | object | `{}` |  |
| nl2dsl.readinessProbe.httpGet.path | string | `"/"` |  |
| nl2dsl.readinessProbe.httpGet.port | string | `"http"` |  |
| nl2dsl.readinessProbe.initialDelaySeconds | int | `10` |  |
| nl2dsl.readinessProbe.periodSeconds | int | `5` |  |
| nl2dsl.replicaCount | int | `1` |  |
| nl2dsl.resources | object | `{}` |  |
| nl2dsl.service.port | int | `3002` |  |
| nl2dsl.service.type | string | `"ClusterIP"` |  |
| nl2dsl.tolerations | list | `[]` |  |
| ollama.enabled | bool | `true` |  |
| ollama.ollama.models.pull[0] | string | `"gpt-oss:20b"` |  |
| ollama.persistentVolume.enabled | bool | `true` |  |
| ollama.persistentVolume.size | string | `"10Gi"` |  |
| ollama.persistentVolume.storageClass | string | `""` |  |
| ollama.resources | object | `{}` |  |
| ollama.service.port | int | `11434` |  |
| ollama.service.type | string | `"ClusterIP"` |  |
| podAnnotations | object | `{}` |  |
| podLabels | object | `{}` |  |
| podSecurityContext | object | `{}` |  |
| securityContext | object | `{}` |  |
| serviceAccount.annotations | object | `{}` |  |
| serviceAccount.automount | bool | `true` |  |
| serviceAccount.create | bool | `true` |  |
| serviceAccount.name | string | `""` |  |
| webapp.affinity | object | `{}` |  |
| webapp.enabled | bool | `true` |  |
| webapp.env.RANDOM_DATA | string | `"false"` |  |
| webapp.image.pullPolicy | string | `"IfNotPresent"` |  |
| webapp.image.repository | string | `"cogstacksystems/cogstack-cohorter-webapp"` |  |
| webapp.image.tag | string | `"latest"` |  |
| webapp.livenessProbe.httpGet.path | string | `"/"` |  |
| webapp.livenessProbe.httpGet.port | string | `"http"` |  |
| webapp.livenessProbe.initialDelaySeconds | int | `60` |  |
| webapp.livenessProbe.periodSeconds | int | `15` |  |
| webapp.nodeSelector | object | `{}` |  |
| webapp.persistence.accessMode | string | `"ReadWriteOnce"` |  |
| webapp.persistence.enabled | bool | `true` |  |
| webapp.persistence.existingClaim | string | `""` |  |
| webapp.persistence.size | string | `"5Gi"` |  |
| webapp.persistence.storageClass | string | `""` |  |
| webapp.readinessProbe.httpGet.path | string | `"/"` |  |
| webapp.readinessProbe.httpGet.port | string | `"http"` |  |
| webapp.readinessProbe.initialDelaySeconds | int | `30` |  |
| webapp.readinessProbe.periodSeconds | int | `10` |  |
| webapp.replicaCount | int | `1` |  |
| webapp.resources | object | `{}` |  |
| webapp.service.port | int | `3000` |  |
| webapp.service.type | string | `"ClusterIP"` |  |
| webapp.tolerations | list | `[]` |  |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
