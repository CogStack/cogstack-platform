{{/*
Expand the name of the chart.
*/}}
{{- define "cogstack-ce-helm.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "cogstack-ce-helm.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "cogstack-ce-helm.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "cogstack-ce-helm.labels" -}}
helm.sh/chart: {{ include "cogstack-ce-helm.chart" . }}
{{ include "cogstack-ce-helm.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "cogstack-ce-helm.selectorLabels" -}}
app.kubernetes.io/name: {{ include "cogstack-ce-helm.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "cogstack-ce-helm.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "cogstack-ce-helm.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Dependency URLs
*/}}

{{- define "opensearch.url" -}}
{{- if .Values.opensearch.enabled }}
{{- $serviceName := include "opensearch.serviceName" (index .Subcharts "opensearch") -}}
{{- $scheme := default "https" .Values.opensearch.protocol -}}
{{- $port := default 9200 .Values.opensearch.httpPort -}}
{{- printf "%s://%s:%v" $scheme $serviceName $port -}}
{{- else -}}
"opensearch-disabled"
{{- end}}
{{- end }}

{{- define "opensearch-dashboards.url" -}}
{{- $serviceName := include "opensearch-dashboards.fullname" (index .Subcharts "opensearch-dashboards") -}}
{{- $scheme := "http" -}}
{{- $port := default 5601 (index .Values "opensearch-dashboards" "service" "port") -}}
{{- printf "%s://%s:%v" $scheme $serviceName $port -}}
{{- end }}

{{- define "opensearch.initialAdminPassword" -}}
{{- $val := "" -}}
{{- range .Values.opensearch.extraEnvs }}
  {{- if eq .name "OPENSEARCH_INITIAL_ADMIN_PASSWORD" }}
    {{- $val = .value -}}
  {{- end }}
{{- end }}
{{- $val -}}
{{- end }}

