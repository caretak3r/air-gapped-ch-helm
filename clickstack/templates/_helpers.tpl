{{/*
Expand the name of the chart.
*/}}
{{- define "clickstack.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "clickstack.fullname" -}}
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
{{- define "clickstack.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "clickstack.labels" -}}
helm.sh/chart: {{ include "clickstack.chart" . }}
{{ include "clickstack.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "clickstack.selectorLabels" -}}
app.kubernetes.io/name: {{ include "clickstack.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "clickstack.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "clickstack.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Globally available service endpoints from subcharts
These make subchart endpoints available throughout the umbrella chart
*/}}

{{/*
ClickHouse Compute Service Endpoint
*/}}
{{- define "global.clickhouseComputeEndpoint" -}}
{{- $subchart := .Values.clickhouseCompute -}}
{{- if $subchart.enabled -}}
{{- $context := dict "Values" $subchart "Release" .Release "Chart" (dict "Name" "clickhouse-compute" "Version" "0.1.0") -}}
{{- include "clickhouse-compute.endpoint" $context -}}
{{- else -}}
{{- "" -}}
{{- end -}}
{{- end }}

{{/*
Product Metrics Query Service Endpoint  
*/}}
{{- define "global.pmqsEndpoint" -}}
{{- $subchart := .Values.pmqs -}}
{{- if $subchart.enabled -}}
{{- if $subchart.service.enabled -}}
{{- $context := dict "Values" $subchart "Release" .Release "Chart" (dict "Name" "product-metrics-query-service" "Version" "0.1.0") -}}
{{- include "product-metrics-query-service.endpoint" $context -}}
{{- else -}}
{{- "pmqs-service-disabled" -}}
{{- end -}}
{{- else -}}
{{- "pmqs-disabled" -}}
{{- end -}}
{{- end }}

{{/*
Dynamically generate endpoints for all enabled subcharts using .Subcharts
*/}}
{{- define "global.allEndpointsDynamic" -}}
{{- $endpoints := dict -}}
{{- range $subchartName, $subchartContext := .Subcharts -}}
  {{- $valuesKey := $subchartName -}}
  {{- $endpointHelperName := printf "%s.endpoint" $subchartName -}}
  {{- if eq $subchartName "clickhouse-compute" -}}
  {{- $valuesKey = "clickhouseCompute" -}}
  {{- end -}}
  {{- if eq $subchartName "product-metrics-query-service-query-service" -}}
  {{- $valuesKey = "pmqs" -}}
  {{- $endpointHelperName = "product-metrics-query-service.endpoint" -}}
  {{- end -}}
  {{- $subchartValues := index $.Values $valuesKey -}}
  {{- if and $subchartValues $subchartValues.enabled -}}
    {{/* Check if service is enabled for this subchart */}}
    {{- if or (not $subchartValues.service) $subchartValues.service.enabled -}}
      {{/* Generate endpoint using the subchart's own helper with proper values context */}}
      {{- $mergedContext := dict "Values" $subchartValues "Release" $.Release "Chart" $subchartContext.Chart }}
      {{- $endpointValue := include $endpointHelperName $mergedContext | default "" -}}
      {{- if $endpointValue -}}
        {{- $endpoints = set $endpoints $subchartName $endpointValue -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- $endpoints | toYaml -}}
{{- end }}

{{/*
Get enabled subcharts dynamically
*/}}
{{- define "global.enabledSubcharts" -}}
{{- $enabledCharts := list -}}
{{- range $subchartName, $subchartContext := .Subcharts -}}
  {{- $valuesKey := $subchartName -}}
  {{- if eq $subchartName "clickhouse-compute" -}}
  {{- $valuesKey = "clickhouseCompute" -}}
  {{- end -}}
  {{- if eq $subchartName "product-metrics-query-service-query-service" -}}
  {{- $valuesKey = "pmqs" -}}
  {{- end -}}
  {{- $subchartValues := index $.Values $valuesKey -}}
  {{- if and $subchartValues $subchartValues.enabled -}}
    {{- if or (not $subchartValues.service) $subchartValues.service.enabled -}}
      {{- $enabledCharts = append $enabledCharts $subchartName -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- $enabledCharts | toJson -}}
{{- end }}

{{/*
Get service endpoint for a specific subchart
*/}}
{{- define "global.subchartEndpoint" -}}
{{- $subchartName := .subchartName -}}
{{- $rootContext := .rootContext -}}
{{- if $subchartName -}}
  {{- $subchartContext := index $rootContext.Subcharts $subchartName -}}
  {{- if $subchartContext -}}
    {{- $endpointName := printf "%s.endpoint" $subchartName -}}
    {{- include $endpointName $subchartContext -}}
  {{- end -}}
{{- end -}}
{{- end }}

{{/*
All service endpoints as a dynamic single variable
*/}}
{{- define "global.allEndpoints" -}}
{{- include "global.allEndpointsDynamic" . -}}
{{- end }}
