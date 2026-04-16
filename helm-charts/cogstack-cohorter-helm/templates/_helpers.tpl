{{/*
Expand the name of the chart.
*/}}
{{- define "cogstack-cohort.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "cogstack-cohort.fullname" -}}
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
Chart name and version label.
*/}}
{{- define "cogstack-cohort.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels.
*/}}
{{- define "cogstack-cohort.labels" -}}
helm.sh/chart: {{ include "cogstack-cohort.chart" . }}
{{ include "cogstack-cohort.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: cogstack
{{- end }}

{{/*
Selector labels.
*/}}
{{- define "cogstack-cohort.selectorLabels" -}}
app.kubernetes.io/name: {{ include "cogstack-cohort.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Service account name.
*/}}
{{- define "cogstack-cohort.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "cogstack-cohort.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
NL2DSL component labels / selector labels.
*/}}
{{- define "cogstack-cohort.nl2dsl.labels" -}}
{{ include "cogstack-cohort.labels" . }}
app.kubernetes.io/component: nl2dsl
{{- end }}

{{- define "cogstack-cohort.nl2dsl.selectorLabels" -}}
{{ include "cogstack-cohort.selectorLabels" . }}
app.kubernetes.io/component: nl2dsl
{{- end }}

{{/*
WebApp component labels / selector labels.
*/}}
{{- define "cogstack-cohort.webapp.labels" -}}
{{ include "cogstack-cohort.labels" . }}
app.kubernetes.io/component: webapp
{{- end }}

{{- define "cogstack-cohort.webapp.selectorLabels" -}}
{{ include "cogstack-cohort.selectorLabels" . }}
app.kubernetes.io/component: webapp
{{- end }}

{{/*
Fully-qualified service name for the ollama subchart.
The otwld/ollama chart names its service <release>-ollama.
*/}}
{{- define "cogstack-cohort.ollamaServiceName" -}}
{{- printf "%s-ollama" .Release.Name }}
{{- end }}

{{/*
Fully-qualified service name for the medcat subchart.
The medcat-service-helm chart names its service <release>-medcat.
*/}}
{{- define "cogstack-cohort.medcatServiceName" -}}
{{- printf "%s-medcat" .Release.Name }}
{{- end }}
