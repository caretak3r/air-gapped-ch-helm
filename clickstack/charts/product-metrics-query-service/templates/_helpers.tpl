{{/*
Expand the name of the chart.
*/}}
{{- define "product-metrics-query-service.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "product-metrics-query-service.fullname" -}}
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
{{- define "product-metrics-query-service.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "product-metrics-query-service.labels" -}}
helm.sh/chart: {{ include "product-metrics-query-service.chart" . }}
{{ include "product-metrics-query-service.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "product-metrics-query-service.selectorLabels" -}}
app.kubernetes.io/name: {{ include "product-metrics-query-service.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "product-metrics-query-service.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "product-metrics-query-service.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Return the service FQDN with port for product-metrics-query-service
Usage: {{ include "product-metrics-query-service.endpoint" . }}
Returns: product-metrics-query-service.namespace.svc.cluster.local:80
This helper can be called from other charts like:
{{ include "product-metrics-query-service.endpoint" .Values.product-metrics-query-service }}
*/}}
{{- define "product-metrics-query-service.endpoint" -}}
{{- if .Values.service.enabled -}}
{{- $serviceName := include "product-metrics-query-service.fullname" . -}}
{{- printf "%s.%s.svc.cluster.local:%.0f" $serviceName .Release.Namespace .Values.service.port -}}
{{- end -}}
{{- end }}
