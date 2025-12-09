{{/*
Expand the name of the chart.
*/}}
{{- define "clickhouse-compute.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "clickhouse-compute.fullname" -}}
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
{{- define "clickhouse-compute.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "clickhouse-compute.labels" -}}
helm.sh/chart: {{ include "clickhouse-compute.chart" . }}
{{ include "clickhouse-compute.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "clickhouse-compute.selectorLabels" -}}
app.kubernetes.io/name: {{ include "clickhouse-compute.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "clickhouse-compute.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "clickhouse-compute.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Return the kind of controller to use
*/}}
{{- define "clickhouse-compute.controller.kind" -}}
{{- if .Values.controller.kind }}
{{- .Values.controller.kind }}
{{- else }}
{{- "Deployment" }}
{{- end }}
{{- end }}

{{/*
Return the service FQDN with port for clickhouse service
Usage: {{ include "clickhouse-compute.endpoint" . }}
Returns: clickhouse-compute-clickhouse.namespace.svc.cluster.local:8123
This helper can be called from other charts like:
{{ include "clickhouse-compute.endpoint" .Values.clickhouse-compute }}
*/}}
{{- define "clickhouse-compute.endpoint" -}}
{{- if .Values.service.enabled -}}
{{- $serviceName := printf "%s-clickhouse" (include "clickhouse-compute.fullname" .) -}}
{{- printf "%s.%s.svc.cluster.local:8123" $serviceName .Release.Namespace -}}
{{- end -}}
{{- end }}
