# CogStack JupyterHub Helm Chart

## Overview

This chart deploys the upstream [`jupyterhub`](https://hub.jupyter.org/helm-chart/) Helm chart with CogStack defaults (hub/singleuser images) and optional example notebooks bundled as a ConfigMap.

## Prerequisites

- Kubernetes cluster
- Helm 3+

## Installation

Install from a local checkout:

```bash
helm install jupyterhub oci://registry-1.docker.io/cogstacksystems/cogstack-jupyterhub-helm
```

## Configuration

### Change the Docker image version

The most common change is bumping the hub and single-user image tags:

```yaml
jupyterhub:
  hub:
    image:
      tag: "2.2.2"
  singleuser:
    image:
      tag: "2.2.2"
```

### JupyterHub Configuration

All configuration is passed through under the `jupyterhub.*` key (see `values.yaml` for the full default set). Commonly customized values include:

- `jupyterhub.hub.config.*` (authenticator and hub config)
- `jupyterhub.singleuser.image.*` (user image)
- `jupyterhub.proxy.service.type`

See the upstream JupyterHub documentation which lists every option [z2jh.jupyter.org](https://z2jh.jupyter.org/en/stable/resources/reference.html)

### User culling

Enable culling of idle user pods. This will delete pods that are unused and free up resources

```yaml
jupyterhub:
  cull:
    enabled: true
    every: 600
```

### Authentication

The default configuration uses the JupyterHub `DummyAuthenticator` (not for production).

One option for you may be to setup the FirstUseAuthenticator. This will let any new user login and set their own passwords.

```yaml
jupyterhub:
    hub:
        config:
        JupyterHub:
            authenticator_class: firstuseauthenticator.FirstUseAuthenticator
        Authenticator:
            admin_users:
            - admin
```

Refer to the JupyterHub docs for other authentication settings on [z2jh](https://z2jh.jupyter.org/en/stable/administrator/authentication.html#general-configuration)

### OAuth / OIDC

JupyterHub can be setup with OAuth2 based authentication.

See [Enabling OIDC Authentication](https://github.com/CogStack/cogstack-jupyter-hub/blob/main/README.md#enabling-oidc-authentication).

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| https://hub.jupyter.org/helm-chart/ | jupyterhub | 4.3.2 |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| jupyterhub.cull.enabled | bool | false, so pods stay running indefinitely | Enable culling of user pods |
| jupyterhub.hub.config.Authenticator.admin_users[0] | string | `"admin"` |  |
| jupyterhub.hub.config.DummyAuthenticator.password | string | `"SuperSecret"` |  |
| jupyterhub.hub.config.JupyterHub.authenticator_class | string | `"dummy"` |  |
| jupyterhub.hub.config.KubeSpawner.fs_gid | int | `0` |  |
| jupyterhub.hub.config.KubeSpawner.http_timeout | int | `120` |  |
| jupyterhub.hub.config.KubeSpawner.notebook_dir | string | `"/home/jovyan/work"` |  |
| jupyterhub.hub.config.KubeSpawner.start_timeout | int | `300` |  |
| jupyterhub.hub.config.KubeSpawner.uid | int | `0` |  |
| jupyterhub.hub.config.Spawner.default_url | string | `"/lab/"` |  |
| jupyterhub.hub.config.Spawner.notebook_dir | string | `"/home/jovyan/work"` |  |
| jupyterhub.hub.extraConfig | object | `{"00-custom-spawner":"# Custom environment variables for user pods\nc.KubeSpawner.environment = c.KubeSpawner.environment or {}\nc.KubeSpawner.environment.update({\n  'GRANT_SUDO': '1',\n  'CHOWN_HOME': 'yes',\n  'CHOWN_HOME_OPTS': '-R',\n})\n# Allow root in notebooks\nc.KubeSpawner.args = ['--allow-root']\n","00-log-level":"c.Application.log_level = 'DEBUG'\n","01-prometheus-authentication":"c.JupyterHub.authenticate_prometheus = False\n"}` | Extra hub configuration for custom spawner settings |
| jupyterhub.hub.extraConfig.01-prometheus-authentication | string | `"c.JupyterHub.authenticate_prometheus = False\n"` | Allow /hub/metrics to be scraped without authentication |
| jupyterhub.hub.image.name | string | `"cogstacksystems/jupyter-hub"` | Image repository for the JupyterHub hub. |
| jupyterhub.hub.image.pullPolicy | string | `"IfNotPresent"` | Pull policy for the JupyterHub hub. |
| jupyterhub.hub.image.tag | string | `"2.2.2"` | Image tag for the JupyterHub hub. |
| jupyterhub.hub.networkPolicy.ingress[0].from[0].podSelector.matchLabels."app.kubernetes.io/name" | string | `"prometheus"` |  |
| jupyterhub.hub.networkPolicy.ingress[0].ports[0].port | string | `"http"` |  |
| jupyterhub.hub.networkPolicy.ingress[0].ports[0].protocol | string | `"TCP"` |  |
| jupyterhub.prePuller.continuous.enabled | bool | `false` |  |
| jupyterhub.prePuller.hook | object | `{"enabled":false}` | Enable pulling the singleuser image before they are used to improve startup time |
| jupyterhub.proxy.service.type | string | `"ClusterIP"` |  |
| jupyterhub.scheduling.userScheduler.replicas | int | `1` |  |
| jupyterhub.singleuser.cmd[0] | string | `"jupyterhub-singleuser"` |  |
| jupyterhub.singleuser.extraPodConfig | object | `{"securityContext":{"runAsGroup":0,"runAsUser":0}}` | Extra arguments passed to jupyterhub-singleuser |
| jupyterhub.singleuser.fsGid | int | `0` |  |
| jupyterhub.singleuser.image.name | string | `"cogstacksystems/jupyter-singleuser"` |  |
| jupyterhub.singleuser.image.pullPolicy | string | `"IfNotPresent"` |  |
| jupyterhub.singleuser.image.tag | string | `"2.2.2"` |  |
| jupyterhub.singleuser.lifecycleHooks.postStart | object | `{"exec":{"command":["sh","-c","if [ ! -f /home/jovyan/work/.notebooks_initialized ]; then\n  echo \"First run - copying notebooks and medcat-scripts...\";\n  cp -r /srv/jupyterhub/notebooks/* /home/jovyan/work/;\n  cp -r /srv/jupyterhub/medcat-scripts /home/jovyan/work/;\n  touch /home/jovyan/work/.notebooks_initialized;\n  echo \"Notebooks initialized successfully\";\nelse\n  echo \"Notebooks already initialized - skipping\";\nfi\n"]}}` | Lifecycle hook to copy notebooks from image to PVC on first run |
| jupyterhub.singleuser.networkPolicy.enabled | bool | `false` |  |
| jupyterhub.singleuser.startTimeout | int | `600` |  |
| jupyterhub.singleuser.storage.capacity | string | `"5Gi"` | Capacity of the storage for the user pods. |
| jupyterhub.singleuser.storage.extraVolumeMounts.jupyter-examples.mountPath | string | `"/home/jovyan/work/examples"` |  |
| jupyterhub.singleuser.storage.extraVolumeMounts.jupyter-examples.name | string | `"jupyter-examples"` |  |
| jupyterhub.singleuser.storage.extraVolumeMounts.jupyter-examples.readOnly | bool | `true` |  |
| jupyterhub.singleuser.storage.extraVolumes | object | `{"jupyter-examples":{"configMap":{"name":"jupyter-examples"},"name":"jupyter-examples"}}` | NOTE: Prefer dictionary-form here to avoid Helm merge issues when this subchart is configured by a parent chart. |
| jupyterhub.singleuser.uid | int | `0` |  |
| serviceMonitor | object | `{"enabled":false,"interval":"30s","labels":{},"path":"/hub/metrics","port":"hub","scheme":"http","tlsConfig":{}}` | Create a Prometheus ServiceMonitor for the JupyterHub. Requires the Prometheus Operator to be installed |
| serviceMonitor.enabled | bool | `false` | Set to true to enable creation of a ServiceMonitor resource |
| serviceMonitor.interval | string | `"30s"` | Frequency at which Prometheus will scrape metrics. |
| serviceMonitor.labels | object | `{}` | Additional labels to be added to the ServiceMonitor |
| serviceMonitor.path | string | `"/hub/metrics"` | HTTP path where metrics are exposed. |
| serviceMonitor.port | string | `"hub"` | Named port the serviceMonitor will scrape. |
| serviceMonitor.scheme | string | `"http"` | Scheme to use for scraping. |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)