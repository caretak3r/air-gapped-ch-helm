# Service Endpoints Integration Guide

This guide explains how new Helm charts added as dependencies to the umbrella chart can utilize the service endpoints ConfigMap for inter-service communication.

## Overview

The umbrella chart automatically creates a `ConfigMap` named `{release-name}-service-endpoints` that contains dynamically generated service endpoints for all enabled subcharts. This allows services to discover and communicate with each other without hardcoding service details.

## ConfigMap Structure

The endpoints ConfigMap contains:

### 1. Individual Endpoint Variables
```yaml
data:
  # Simple key-value pairs for each enabled service
  pmqs-endpoint: "control-plane-pmqs.namespace.svc.cluster.local:3000"
  clickhouse-endpoint: "control-plane-clickhouse-clickhouse.namespace.svc.cluster.local:8123"
```

### 2. YAML Structure
```yaml
data:
  # Complete structured data as YAML
  service-endpoints.yaml: |
    pmqs: "control-plane-pmqs.namespace.svc.cluster.local:3000"
    clickhouse: "control-plane-clickhouse-clickhouse.namespace.svc.cluster.local:8123"
```

### 3. Subchart Information
```yaml
data:
  # Metadata about each subchart
  subcharts-info.yaml: |
    pmqs:
      chart:
        name: product-metrics-query-service
        version: "0.1.0"
        appVersion: "1.0.0"
      enabled: true
      service:
        enabled: true
    clickhouse:
      chart:
        name: clickhouse
        version: "0.1.0"
        appVersion: "25.7.0"
      enabled: true
```

## Requirements for New Helm Charts

### 1. **Required Template Helper**

Each new service chart **MUST** define an `.endpoint` helper in its `_helpers.tpl`:

```yaml
{{/*
Return the service FQDN with port for your-service
Usage: {{ include "your-service.endpoint" . }}
Returns: your-service.namespace.svc.cluster.local:8080
*/}}
{{- define "your-service.endpoint" -}}
{{- if .Values.service.enabled -}}
{{- $serviceName := include "your-service.fullname" . -}}
{{- $port := .Values.service.port | default 8080 -}}
{{- printf "%s.%s.svc.cluster.local:%.0f" $serviceName .Release.Namespace $port -}}
{{- end -}}
{{- end }}
```

### 2. **Standard Service Configuration**

Your service should have a standard `service` configuration block:

```yaml
# values.yaml
service:
  enabled: true
  type: ClusterIP
  port: 8080
  # Other service settings...
```

### 3. **Optional: Environment Variable Support**

Your chart can automatically consume endpoints from the ConfigMap:

```yaml
# templates/deployment.yaml
env:
  # Method 1: Load individual endpoints
  - name: CLICKHOUSE_ENDPOINT
    valueFrom:
      configMapKeyRef:
        name: {{ include "control-plane.fullname" . }}-service-endpoints
        key: clickhouse-endpoint
  
  # Method 2: Load endpoints from YAML structure
  - name: SERVICE_ENDPOINTS
    valueFrom:
      configMapKeyRef:
        name: {{ include "control-plane.fullname" . }}-service-endpoints
        key: service-endpoints.yaml
```

## Implementation Patterns

### Pattern 1: Direct Environment Variable Injection

Add to your deployment template:

```yaml
# templates/deployment.yaml
env:
  {{- range $key, $value := .Values.dependsOn.services }}
  {{- $endpointKey := printf "%s-endpoint" $key }}
  - name: {{ printf "%s_ENDPOINT" $key | upper }}
    valueFrom:
      configMapKeyRef:
        name: {{ $.Release.Name }}-service-endpoints
        key: {{ $endpointKey }}
        optional: true
  {{- end }}
```

With corresponding values:

```yaml
# values.yaml
dependsOn:
  services:
    - clickhouse
    - pmqs
    - redis
```

### Pattern 2: ConfigMap Volume Mount

Create a volume that contains the endpoints:

```yaml
# templates/deployment.yaml
volumes:
  - name: service-endpoints
    configMap:
      name: {{ include "control-plane.fullname" . }}-service-endpoints
      
volumeMounts:
  - name: service-endpoints
    mountPath: /etc/service-endpoints
    readOnly: true
```

### Pattern 3: Init Container for Environment Setup

Use an init container to parse endpoints and set environment variables:

```yaml
# templates/deployment.yaml
initContainers:
  - name: setup-endpoints
    image: busybox:1.35
    command:
      - /bin/sh
      - -c
      - |
        # Extract endpoints from ConfigMap and export as env vars
        echo "Setting up service endpoints..."
        cat /etc/service-endpoints/service-endpoints.yaml > /tmp/env-config
        
    volumeMounts:
      - name: service-endpoints
        mountPath: /etc/service-endpoints
      - name: env-config
        mountPath: /tmp/env-config
```

## Adding New Services to Umbrella Chart

### 1. Update Umbrella Chart Dependencies

```yaml
# Chart.yaml
dependencies:
  - name: pmqs
    version: "0.1.0"
    repository: "file://charts/pmqs"
  - name: clickhouse-operator
    version: "0.1.0"
    repository: "file://charts/clickhouse-operator"
  - name: your-new-service
    version: "0.1.0"
    repository: "file://charts/your-new-service"
```

### 2. Add Values Configuration

```yaml
# values.yaml
your-new-service:
  enabled: true
  service:
    enabled: true
    type: ClusterIP
    port: 8080
```

### 3. Integration with Existing Services

New services can automatically discover existing services:

```yaml
# your-new-service/values.yaml
dependsOn:
  - clickhouse
  - pmqs
```

```yaml
# your-new-service/templates/deployment.yaml
env:
  - name: CLICKHOUSE_ENDPOINT
    valueFrom:
      configMapKeyRef:
        name: {{ include "control-plane.fullname" . }}-service-endpoints
        key: clickhouse-endpoint
  - name: PMQS_ENDPOINT
    valueFrom:
      configMapKeyRef:
        name: {{ include "control-plane.fullname" . }}-service-endpoints
        key: pmqs-endpoint
```

## Example: Adding a Redis Service

### 1. Redis Chart Structure
```
charts/redis/
├── Chart.yaml
├── values.yaml
├── templates/
│   ├── _helpers.tpl
│   ├── deployment.yaml
│   ├── service.yaml
│   └── configmap.yaml
```

### 2. Redis Endpoint Helper
```yaml
# charts/redis/templates/_helpers.tpl
{{/*
Return the service FQDN with port for redis
*/}}
{{- define "redis.endpoint" -}}
{{- if .Values.service.enabled -}}
{{- $serviceName := include "redis.fullname" . -}}
{{- $port := .Values.service.port | default 6379 -}}
{{- printf "%s.%s.svc.cluster.local:%.0f" $serviceName .Release.Namespace $port -}}
{{- end -}}
{{- end }}
```

### 3. Redis Service Configuration
```yaml
# charts/redis/values.yaml
service:
  enabled: true
  type: ClusterIP
  port: 6379
```

### 4. Add to Umbrella Chart
```yaml
# values.yaml
redis:
  enabled: true
  replicaCount: 1
  service:
    enabled: true
    port: 6379
```

### 5. Other Services Can Now Use Redis
```yaml
# pmqs/templates/deployment.yaml
env:
  - name: REDIS_ENDPOINT
    valueFrom:
      configMapKeyRef:
        name: {{ include "control-plane.fullname" . }}-service-endpoints
        key: redis-endpoint
```

## Best Practices

### 1. **Naming Convention**
- Use consistent service naming: `{{ .Release.Name }}-{{ .Chart.Name }}`
- Follow pattern for endpoint helpers: `{chart-name}.endpoint`

### 2. **Port Management**
- Always check `service.enabled` before generating endpoints
- Use default values for ports to ensure endpoint generation works

### 3. **Error Handling**
- Mark ConfigMap keys as `optional: true` when referencing endpoints
- Provide fallback values when services might be disabled

### 4. **Testing**
```bash
# Verify endpoints ConfigMap
kubectl get configmap control-plane-service-endpoints -o yaml

# Test service discovery
kubectl exec deployment/your-service -- env | grep ENDPOINT
```

### 5. **Documentation**
- Document which services your chart depends on
- Include examples of endpoint usage in your chart's README

## Troubleshooting

### Common Issues

1. **Missing Endpoint in ConfigMap**
   - Ensure subchart has the `.endpoint` helper defined
   - Verify service is enabled in values
   - Check that umbrella chart dependency is configured

2. **Service Cannot Reach Endpoint**
   - Verify network policies allow inter-service communication
   - Check service endpoints are correct: `kubectl get svc`
   - Ensure services are in the same namespace

3. **ConfigMap Not Found**
   - Ensure the umbrella chart deployment uses the correct release name
   - Check if the ConfigMap exists: `kubectl get configmap`

### Debug Commands

```bash
# Check ConfigMap contents
kubectl get configmap $(helm ls -q)-service-endpoints -o yaml

# Verify service discovery
kubectl run test-pod --image=busybox --rm -it -- \
  sh -c 'nslookup service-name.namespace.svc.cluster.local'

# Check endpoint helper output
helm template . --show-only templates/your-service/templates/_helpers.tpl | grep endpoint
```

This pattern enables automatic service discovery for all charts in the umbrella deployment, making it easy to add new services and maintain inter-service communication without manual configuration.
