# CogStack Observability Helm Chart

This chart installs the observability stack for a CogStack deployment on Kubernetes.

It is a wrapper around the kube-prometheus-stack, aiming to provide a simple way to get with observability for cogstack services.

## Overview

This chart deploys:

| Component | Description |
|-----------|-------------|
| **kube-prometheus-stack** | Prometheus Operator stack for metrics collection, rules, and monitoring components. |
| **Prometheus** | Scrapes metrics from CogStack services and stores time series data. |
| **Grafana** | Provides dashboards for visualising CogStack platform health and service metrics. |
| **Bundled dashboards** | Preloads dashboards for CogStack availability, FastAPI metrics, and OpenSearch metrics. |

This chart is intended to be installed alongside a CogStack deployment that exposes metrics through `ServiceMonitor`, `PodMonitor`, `Probe`, or related Prometheus resources.

## Prerequisites

- Kubernetes cluster
- Helm 3+
- A CogStack deployment with metrics endpoints enabled

## Installation

```sh
helm install observability oci://registry-1.docker.io/cogstacksystems/cogstack-observability-helm
```

If you are deploying this alongside `cogstack-ce-helm`, you can enable the required monitors in the CE chart with the example override file at `../cogstack-ce-helm/values-observability.yaml`.

## Configuration
These are some values that are likely to need customization for your deployment:

| Value | Default | Description |
|-------|---------|-------------|
| `kube-prometheus-stack.enabled` | `true` | Main switch for installing the bundled `kube-prometheus-stack`. Set this to `false` if your cluster already provides Prometheus and Grafana. |
| `kube-prometheus-stack.crds.enabled` | `true` | Controls installation of Prometheus Operator CRDs. Set this to `false` when the CRDs are already installed and managed elsewhere. |
| `kube-prometheus-stack.grafana.sidecar.dashboards.enabled` | `true` | Enables Grafana sidecar dashboard discovery for the dashboards shipped by this chart. Set this to `false` if Grafana or dashboard loading is handled externally. |
| `kube-prometheus-stack.grafana.adminUser` | `"admin"` | Grafana admin username. |
| `kube-prometheus-stack.grafana.adminPassword` | `"grafana-admin-password"` | Grafana admin password; change this for any real deployment. |
| `kube-prometheus-stack.grafana.service.*` | not set | Configure how Grafana is exposed, for example `ClusterIP`, `NodePort`, or `LoadBalancer`. |
| `kube-prometheus-stack.prometheus.service.*` | not set | Configure how Prometheus is exposed if direct access is required. |
| `kube-prometheus-stack.prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues` | `false` | Allows Prometheus to discover `ServiceMonitor` resources not created by this chart. |
| `kube-prometheus-stack.prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues` | `false` | Allows Prometheus to discover `PodMonitor` resources not created by this chart. |
| `kube-prometheus-stack.prometheus.prometheusSpec.probeSelectorNilUsesHelmValues` | `false` | Allows Prometheus to discover `Probe` resources not created by this chart. |
| `kube-prometheus-stack.prometheus.prometheusSpec.ruleSelectorNilUsesHelmValues` | `false` | Allows Prometheus to discover `PrometheusRule` resources not created by this chart. |
| `kube-prometheus-stack.prometheus.prometheusSpec.scrapeConfigSelectorNilUsesHelmValues` | `false` | Allows Prometheus to discover additional `ScrapeConfig` resources not created by this chart. |

Example override file:

```yaml
# my-values.yaml
kube-prometheus-stack:
  enabled: false
  crds:
    enabled: false
  grafana:
    sidecar:
      dashboards:
        enabled: false
```

Install with overrides:

```bash
helm install cogstack-observability . -f my-values.yaml --namespace observability --create-namespace
```

## Dependencies

The chart depends on:

- `kube-prometheus-stack`

## Uninstall

```bash
helm uninstall cogstack-observability --namespace observability
```

If the namespace was created only for this release, remove it with:

```bash
kubectl delete namespace observability
```

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| oci://ghcr.io/prometheus-community/charts | kube-prometheus-stack | 81.2.2 |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| fullnameOverride | string | `""` |  |
| kube-prometheus-stack.crds.enabled | bool | `true` |  |
| kube-prometheus-stack.enabled | bool | `true` |  |
| kube-prometheus-stack.grafana.adminPassword | string | `"grafana-admin-password"` |  |
| kube-prometheus-stack.grafana.adminUser | string | `"admin"` |  |
| kube-prometheus-stack.grafana.enabled | bool | `true` |  |
| kube-prometheus-stack.grafana.sidecar.dashboards.enabled | bool | `true` |  |
| kube-prometheus-stack.prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues | bool | `false` |  |
| kube-prometheus-stack.prometheus.prometheusSpec.probeSelectorNilUsesHelmValues | bool | `false` |  |
| kube-prometheus-stack.prometheus.prometheusSpec.ruleSelectorNilUsesHelmValues | bool | `false` |  |
| kube-prometheus-stack.prometheus.prometheusSpec.scrapeConfigSelectorNilUsesHelmValues | bool | `false` |  |
| kube-prometheus-stack.prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues | bool | `false` |  |
| nameOverride | string | `""` |  |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)