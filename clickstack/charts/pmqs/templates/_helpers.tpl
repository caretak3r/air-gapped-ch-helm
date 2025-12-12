{{/*
Expand the name of the chart.
*/}}
{{- define "pmqs.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "pmqs.fullname" -}}
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
{{- define "pmqs.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "pmqs.labels" -}}
helm.sh/chart: {{ include "pmqs.chart" . }}
{{ include "pmqs.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "pmqs.selectorLabels" -}}
app.kubernetes.io/name: {{ include "pmqs.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "pmqs.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "pmqs.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Return the service FQDN with port for pmqs
Usage: {{ include "pmqs.endpoint" . }}
Returns: pmqs.namespace.svc.cluster.local:80
This helper can be called from other charts like:
{{ include "pmqs.endpoint" .Values.pmqs }}
*/}}
{{- define "pmqs.endpoint" -}}
{{- if .Values.service.enabled -}}
{{- $serviceName := include "pmqs.fullname" . -}}
{{- printf "%s.%s.svc.cluster.local:%.0f" $serviceName .Release.Namespace .Values.service.port -}}
{{- end -}}
{{- end }}

{{/*
Get the ClickHouse credentials secret name
Priority:
1. .Values.secrets.clickhouse-credentials (chart-level override)
2. .Values.global.secrets.clickhouse-credentials (global setting)
3. Empty string (meaning: use default credentials inline)
*/}}
{{- define "pmqs.credentials.secretName" -}}
{{- $chartSecret := index .Values.secrets "clickhouse-credentials" | default "" -}}
{{- $globalSecret := "" -}}
{{- if .Values.global -}}
{{- if .Values.global.secrets -}}
{{- $globalSecret = index .Values.global.secrets "clickhouse-credentials" | default "" -}}
{{- end -}}
{{- end -}}
{{- if $chartSecret -}}
{{ $chartSecret }}
{{- else if $globalSecret -}}
{{ $globalSecret }}
{{- end -}}
{{- end }}

{{/*
Check if we should use a secret reference for ClickHouse credentials
Returns "true" if secret name is provided (chart-level or global), "false" otherwise
*/}}
{{- define "pmqs.credentials.useSecret" -}}
{{- $secretName := include "pmqs.credentials.secretName" . -}}
{{- if $secretName -}}
true
{{- else -}}
false
{{- end -}}
{{- end }}
