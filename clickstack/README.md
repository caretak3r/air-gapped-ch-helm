# ClickStack Helm Chart

A comprehensive umbrella chart for deploying ClickHouse and supporting services in Kubernetes.

## Overview

ClickStack provides following components:

### 🗄️ Components

- **ClickHouse**: High-performance columnar database for analytics and data processing
- **PMQS** (Product Metrics Query Service): Golang service for querying product metrics

### 🚀 Features

- **SQL Script Execution**: Execute custom SQL scripts during pod lifecycle
- **Dynamic Service Discovery**: Automatic endpoint generation and service discovery
- **Multiple Deployment Options**: Support for both standalone and distributed deployments
- **Secrets Integration**: Flexible credential management (internal, external)
- **S3 Storage Tiering**: Native S3 integration for cold data

## Prerequisites

- Kubernetes cluster (v1.20+)
- Helm 3.8+
- Storage provisioner for PersistentVolumes (if using persistent storage)
- ClickHouse client for manual testing (optional)

## Quick Start

### Basic Installation

```bash
# Add the Helm repository
helm repo add clickstack https://your-repo.example.com/clickstack

# Install with default configuration
helm install control-plane ./clickstack

# Install with custom values
helm install control-plane ./clickstack --create-namespace clickstack -f override.yaml
```

### Custom Values (override.yaml)

```yaml
# Enable SQL script execution
clickhouse:
  config:
    users:
      username: "appuser"
      password: "securepassword123"

pmqs:
  enabled: true
  replicaCount: 2
  service:
    port: 8080

global:
  region: us-west-2
  environment: production
  imageRegistry: "your-registry.com"
  imagePullSecrets:
    - name: registry-secret
  secrets:
    clickhouseCredentials: "clickhouse-creds"

clickhouse:
  controller:
    replicas: 3
  serviceAccount:
      create: true
  persistence:
    enabled: true
    dataSize: 100Gi
    logSize: 20Gi
  storage:
    s3:
      enabled: true
      endpoint: https://s3.us-west-2.amazonaws.com
      bucket: clickhouse-data
      region: us-west-2
  scripts:
    enabled: true
    files:
      - "init-database.sql"
      - "setup-permissions.sql"
    delayBetween: 3
```

## Subcharts

### 🗃 ClickHouse

Role: Columnar Database

**Features:**
- High-performance analytical database
- Support for S3 storage tiering
- Configurable retention policies
- User management through xml or external secrets
- SQL script execution for database setup/teardown

**Key Configuration:**
```yaml
clickhouse:
  # User Management
  config:
    users:
      username: ""           # Override external secret
      password: ""           # Override external secret
  
  # Controller Settings
  controller:
    kind: Deployment        # Deployment or StatefulSet
    replicas: 1
    enabled: true
  
  # Storage Configuration
  persistence:
    enabled: false          # Enable persistent storage
    dataSize: 10Gi          # Data volume size
    logSize: 5Gi            # Log volume size
  
  # S3 Integration
  storage:
    s3:
      enabled: false          # Enable S3 storage
      endpoint: ""            # S3 endpoint URL
      bucket: ""             # S3 bucket name
      region: ""              # S3 region
  
  # SQL Scripts
  scripts:
    enabled: false          # Execute SQL during shutdown
    files: []              # List of SQL files
    delayBetween: 2         # Seconds between scripts
```

### 🔧 PMQS (Product Metrics Query Service)

Role: Metrics Query Service

**Features:**
- RESTful API for querying ClickHouse
- SQL query builder functionality
- Service discovery integration
- Configurable authentication
- Health check endpoints

**Key Configuration:**
```yaml
pmqs:
  enabled: true
  replicaCount: 1
  service:
    type: ClusterIP
    port: 3000
    targetPort: 8080
  image:
    repository: your-registry/product-metrics-query-service
    tag: latest
    pullPolicy: Always
  
  # Environment Variables
  env:
    SERVICE_TYPE: "API"
    LOG_LEVEL: "info"
```

## Configuration Reference

### Global Settings

| Parameter | Default | Description |
|-----------|---------|-------------|
| `global.region` | `us-east-1` | AWS region for resources |
| `global.environment` | `production` | Deployment environment |
| `global.imageRegistry` | `""` | Default container registry |
| `global.secrets.clickhouseCredentials` | `""` | External secret name for ClickHouse credentials |
| `global.storageClassName` | `""` | Storage class for PVCs |
| `global.keepPVC` | `false` | Preserve PVCs on uninstall |

### Database Configuration

| Parameter | Default | Description |
|-----------|---------|-------------|
| `clickhouse.config.users.username` | `""` | Override username from external secret |
| `clickhouse.config.users.password` | `""` | Override password from external secret |
| `clickhouse.config.clusterCidrs` | `[10.0.0.0/8,172.16.0.0/12,192.168.0.0/16]` | CIDRs for cluster access control |

### Storage Configuration

| Parameter | Default | Description |
|-----------|---------|-------------|
| `clickhouse.persistence.enabled` | `false` | Enable persistent storage |
| `clickhouse.persistence.dataSize` | `10Gi` | Data volume size |
| `clickhouse.persistence.logSize` | `5Gi` | Log volume size |
| `clickhouse.storage.s3.enabled` | `false` | Enable S3 storage tiering |
| `clickhouse.storage.s3.endpoint` | `""` | S3 endpoint URL |
| `clickhouse.storage.s3.bucket` | `""` | S3 bucket name |
| `clickhouse.storage.s3.region` | `""` | S3 region |

### Scripts Configuration

| Parameter | Default | Description |
|-----------|---------|-------------|
| `clickhouse.scripts.enabled` | `false` | Enable/disable script execution |
| `clickhouse.scripts.files` | `[]` | List of SQL files to execute |
| `clickhouse.scripts.delayBetween` | `2` | Delay between script executions |

## Deployments

### Development Environment

```bash
# Install for development
helm install control-plane ./clickstack \
  --namespace clickstack \
  --set global.secrets.clickhouseCredentials=dev-creds \
  --set clickhouse.controller.replicas=1 \
  --set clickhouse.persistence.enabled=false

# Create external secret
kubectl create secret generic dev-creds \
  --from-literal=username=devuser \
  --from-literal=password=devpass123
```

### Production Environment

```bash
# Install for production
helm install control-plane ./clickstack \
  --namespace production \
  --create-namespace production \
  -f override.yaml \
  --wait

# Override production configuration
kubectl apply -f production-config.yaml
helm upgrade control-plane ./clickstack \
  --namespace production
  --reuse-values -f override.yaml
```

### Production Override Values (production-config.yaml)

```yaml
global:
  region: us-west-2
  environment: production
  imageRegistry: "your-reg.example.com"
  imagePullSecrets:
    - name: prod-registry
      key: Y2xpYWRhbGQ=  # base64 encoded

clickhouse:
  controller:
    replicas: 5
    kind: StatefulSet
  persistence:
    enabled: true
    dataSize: 500Gi
    logSize: 100Gi
  storage:
    s3:
      enabled: true
      endpoint: https://s3.us-west-2.amazonaws.com
      bucket: production-clickhouse
  resources:
    limits:
      cpu: 4000m
      memory: 8Gi
    requests:
      cpu: 2000m
      memory: 4Gi

pmqs:
  replicaCount: 3
  resources:
    limits:
      cpu: 1000m
      memory: 1Gi
    requests:
      cpu: 500m
      memory: 512Mi
  tolerations:
    - key: "node-class"
      operator: "In"
      values:
        - "compute-optimized"
```

## Adding SQL Scripts

### Creating Custom Scripts

1. **Add SQL files** to `charts/clickhouse/data/scripts/`:

```sql
-- Example: database initialization script
CREATE DATABASE IF NOT EXISTS analytics;

CREATE TABLE IF NOT EXISTS analytics.events (
    id UUID DEFAULT generateUUIDv4(),
    timestamp DateTime64(3) DEFAULT now64(),
    event_type String,
    metadata Map(String, String)
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(timestamp)
ORDER BY (event_type, timestamp);
```

2. **Configure script execution**:

```yaml
clickhouse:
  scripts:
    enabled: true
    files:
      - "init-database.sql"
      - "create-tables.sql"
      - "setup-indexes.sql"
    delayBetween: 5
```

### Script Execution

SQL scripts execute during pod termination in this order:

1. **Standard ClickHouse shutdown** (SYSTEM STOP MERGES, etc.)
2. **Your custom scripts** (in `scripts.files` order)
3. **Final sleep** (configurable delay)

Scripts have access to:
- All ClickHouse databases and tables
- System tables for introspection
- Mounted read-only file system at `/scripts`
- Environment variables from the container

## Service Discovery

The umbrella chart automatically generates service endpoints for all enabled subcharts:

```bash
# Get service endpoints
kubectl get configmap control-plane-service-endpoints -o yaml

# Access endpoints in pods
kubectl exec deployment/control-plane-clickhouse-clickhouse -- env | grep CLICKHOUSE_
```

### Available Endpoints

| Service | Endpoint Format | Example |
|--------|-------------------|---------|
| ClickHouse | `service-name.namespace.svc.cluster.local:port` | `control-plane-clickhouse-clickhouse.default.svc.cluster.local:8123` |
| PMQS | `service-name.namespace.svc.cluster.local:port` | `control-plane-pmqs.default.svc.cluster.local:3000` |

## Troubleshooting

### Common Issues

**Pod Not Starting**
```bash
kubectl logs deployment/control-plane-clickhouse-clickhouse
kubectl describe pod <pod-name>
```

**Storage Issues**
```bash
# Check PVC status
kubectl get pvc -n clickstack

# Check storage class availability
kubectl get storageclass
```

**Authentication Issues**  
```bash
# Verify external secret
kubectl get secret clickhouse-creds -o yaml

# Check user mapping
kubectl logs deployment/control-plane-clickhouse-clickhouse | grep CLICKHOUSE
```

**Script Execution Issues**
```bash
# Enable debug logging
helm upgrade control-plane ./clickstack \
  --set clickhouse.scripts.enabled=true \
  --set clickhouse.scripts.delayBetween=1

# Check script execution logs
kubectl logs deployment/control-plane-clickhouse-clickhouse | grep -i "SQL script"
```

### Debug Mode

```bash
# Render templates without installing
helm template control-plane ./clickstack --values override.yaml --debug

# Validate configuration
helm lint ./clickstack
```

## Development

### Local Development

```bash
# Build and test locally
docker build -t test-clickhouse .
helm test ./clickstack --dry-run

# Install with test values
helm test ./clickstack -f test-values.yaml
```

### Package Distribution

```bash
# Package chart for distribution
helm package ./clickstack --version 0.1.0

# Publish to repository
helm push clickstack-0.1.0.tgz
```

## Contributing

### Repository Structure
```
clickstack/
├── charts/
│   ├── clickhouse/
│   │   ├── data/
│   │   │   └── scripts/      # SQL scripts directory
│   │   ├── templates/      # Kubernetes templates
│   │   └── values.yaml      # Chart values
│   └── pmqs/
│       ├── templates/
│       └── values.yaml
├── templates/               # Umbrella chart templates
├── values.yaml              # Umbrella values
└── README.md                # This file
```

### Adding Components

1. Add new subchart dependencies to `Chart.yaml`
2. Create subchart in `charts/` directory
3. Update service discovery templates
4. Add integration tests

### Submitting Changes

```bash
# Standard contribution flow
git checkout -b feature/new-component
# Make your changes
git commit -m "Add new component"
git push origin feature/new-component
hub pull-request create feature/new-component
```

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

## Support

- Create an [issue](https://github.com/your-org/clickstack/issues) for bug reports
- Create a [discussion](https://github.com/your-org/clickstack/discussions) for questions
- Join our [Slack workspace](https://your-org.slack.com) for community support
