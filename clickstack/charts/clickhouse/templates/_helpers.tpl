{{/*
Expand the name of the chart.
*/}}
{{- define "clickhouse.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "clickhouse.fullname" -}}
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
{{- define "clickhouse.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "clickhouse.labels" -}}
helm.sh/chart: {{ include "clickhouse.chart" . }}
{{ include "clickhouse.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "clickhouse.selectorLabels" -}}
app.kubernetes.io/name: {{ include "clickhouse.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "clickhouse.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "clickhouse.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Return the kind of controller to use
*/}}
{{- define "clickhouse.controller.kind" -}}
{{- if .Values.controller.kind }}
{{- .Values.controller.kind }}
{{- else }}
{{- "Deployment" }}
{{- end }}
{{- end }}

{{/*
Return the service FQDN with port for clickhouse service
Usage: {{ include "clickhouse.endpoint" . }}
Returns: clickhouse-clickhouse.namespace.svc.cluster.local:8123
This helper can be called from other charts like:
{{ include "clickhouse.endpoint" .Values.clickhouse }}
*/}}
{{- define "clickhouse.endpoint" -}}
{{- if .Values.service.enabled -}}
{{- $serviceName := printf "%s-clickhouse" (include "clickhouse.fullname" .) -}}
{{- printf "%s.%s.svc.cluster.local:8123" $serviceName .Release.Namespace -}}
{{- end -}}
{{- end }}

{{/*
Get the ClickHouse credentials secret name
Priority:
1. .Values.secrets.clickhouse-credentials (chart-level override)
2. .Values.global.secrets.clickhouse-credentials (global setting)
3. Empty string (meaning: create default secret)
*/}}
{{- define "clickhouse.credentials.secretName" -}}
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
{{- else -}}
{{- /* No external secret specified, will use chart-created secret */ -}}
{{- end -}}
{{- end }}

{{/*
Check if we should use an external (user-provided) secret for credentials
Returns "true" if external secret name is provided, "false" otherwise
*/}}
{{- define "clickhouse.credentials.useExternal" -}}
{{- $secretName := include "clickhouse.credentials.secretName" . -}}
{{- if $secretName -}}
true
{{- else -}}
false
{{- end -}}
{{- end }}

{{/*
Get the actual secret name to reference in pods
If external secret is provided, use that; otherwise use the chart-created secret
*/}}
{{- define "clickhouse.credentials.refName" -}}
{{- $externalSecret := include "clickhouse.credentials.secretName" . -}}
{{- if $externalSecret -}}
{{ $externalSecret }}
{{- else -}}
{{ include "clickhouse.fullname" . }}-credentials
{{- end -}}
{{- end }}

{{/*
Get the effective username for ClickHouse (used when creating default secret)
*/}}
{{- define "clickhouse.credentials.username" -}}
{{- .Values.config.users.username | default "default" -}}
{{- end }}

{{/*
Get the effective password for ClickHouse (used when creating default secret)
*/}}
{{- define "clickhouse.credentials.password" -}}
{{- .Values.config.users.password | default "password" -}}
{{- end }}
