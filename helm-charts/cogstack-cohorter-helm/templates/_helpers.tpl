{{/*
Expand the name of the chart.
*/}}
{{- define "cogstack-cohorter-helm.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "cogstack-cohorter-helm.fullname" -}}
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
{{- define "cogstack-cohorter-helm.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "cogstack-cohorter-helm.labels" -}}
helm.sh/chart: {{ include "cogstack-cohorter-helm.chart" . }}
{{ include "cogstack-cohorter-helm.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "cogstack-cohorter-helm.selectorLabels" -}}
app.kubernetes.io/name: {{ include "cogstack-cohorter-helm.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "cogstack-cohorter-helm.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "cogstack-cohorter-helm.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}


{{/*
Fully-qualified service name for the ollama subchart.
The otwld/ollama chart names its service <release>-ollama.
*/}}
{{- define "cogstack-cohorter-helm.ollamaServiceName" -}}
{{- printf "%s-ollama" .Release.Name }}
{{- end }}

{{/*
Fully-qualified service name for the medcat subchart.
The medcat-service-helm chart names its service <release>-medcat.
*/}}
{{- define "cogstack-cohorter-helm.medcatServiceName" -}}
{{- printf "%s-medcat" .Release.Name }}
{{- end }}
