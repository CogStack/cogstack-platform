{{/*
Expand the name of the chart.
*/}}
{{- define "cogstack-jupyterhub-helm.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "cogstack-jupyterhub-helm.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- $basename := $name | trimSuffix "-helm" }}
{{- if or (contains $name .Release.Name) (eq .Release.Name $basename) }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "cogstack-jupyterhub-helm.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "cogstack-jupyterhub-helm.labels" -}}
helm.sh/chart: {{ include "cogstack-jupyterhub-helm.chart" . }}
{{ include "cogstack-jupyterhub-helm.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: cogstack
{{- end }}

{{/*
Selector labels
*/}}
{{- define "cogstack-jupyterhub-helm.selectorLabels" -}}
app.kubernetes.io/name: {{ include "cogstack-jupyterhub-helm.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
ServiceMonitor selector labels for the jupyterhub hub Service.
This intentionally mirrors the JupyterHub chart's hub service labels.
*/}}
{{- define "jupyterhub.hubMatchLabels" -}}
component: {{ "hub" | quote }}
app: {{ "jupyterhub" | quote }}
release: {{ .Release.Name | quote }}
{{- end -}}
