{{/* vim: set filetype=mustache: */}}
{{- define "cogstack-jupyterhub.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "cogstack-jupyterhub.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "cogstack-jupyterhub.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "cogstack-jupyterhub.labels" -}}
helm.sh/chart: {{ include "cogstack-jupyterhub.chart" . }}
{{ include "cogstack-jupyterhub.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "cogstack-jupyterhub.selectorLabels" -}}
app.kubernetes.io/name: {{ include "cogstack-jupyterhub.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "cogstack-jupyterhub.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "cogstack-jupyterhub.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "cogstack-jupyterhub.envConfigMapName" -}}
{{- printf "%s-env-files" (include "cogstack-jupyterhub.fullname" .) -}}
{{- end -}}

{{- define "cogstack-jupyterhub.hubConfigMapName" -}}
{{- printf "%s-hub-config" (include "cogstack-jupyterhub.fullname" .) -}}
{{- end -}}

{{- define "cogstack-jupyterhub.secretName" -}}
{{- if .Values.securityFiles.existingSecret -}}
{{- .Values.securityFiles.existingSecret -}}
{{- else -}}
{{- printf "%s-hub-secrets" (include "cogstack-jupyterhub.fullname" .) -}}
{{- end -}}
{{- end -}}
