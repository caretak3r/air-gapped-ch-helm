# ClickHouse Operator Migration Guide

This guide documents the migration from a custom ClickHouse Helm chart to the Altinity ClickHouse Operator while maintaining all existing functionality.

## Overview

The migration replaces the current custom ClickHouse deployment with the Altinity ClickHouse Operator while preserving:

- S3 storage integration
- Parquet converter cronjob
- Database initialization scripts
- Service account with IRSA support
- All existing configuration options

## Migration Components

### 1. New Chart Structure
```
charts/clickhouse-operator/
├── Chart.yaml
├── values.yaml
├── templates/
│   ├── _helpers.tpl
│   ├── clickhouseinstallation.yaml
│   ├── serviceaccount.yaml
│   ├── service.yaml
│   └── cronjob.yaml
└── scripts/
    ├── sql-to-shell-converter.sh
    └── setup-irsa.sh
```

### 2. Key Configuration Changes

#### Before (Previous Chart)
```yaml
clickhouse:
  controller:
    replicas: 1
  storage:
    s3:
      enabled: true
  tasks:
    parquetConverter:
      enabled: true
```

#### After (Operator Chart)
```yaml
clickhouse-operator:
  clickhouse:
    replicasCount: 1
    extraConfig: |
      # S3 configuration embedded here
  cronjobs:
    parquetConverter:
      enabled: true
```

## Migration Steps

### 1. Setup IRSA for S3 Access

Run the IRSA setup script to configure least-privilege access to S3:

```bash
# Edit the script with your cluster details
vi charts/clickhouse-operator/scripts/setup-irsa.sh

# Run the script
./charts/clickhouse-operator/scripts/setup-irsa.sh
```

**Key variables to update:**
- `CLUSTER_NAME`: Your EKS cluster name
- `BUCKET_NAME`: Your S3 bucket name
- `NAMESPACE`: Target namespace (default: clickhouse)

### 2. Convert SQL Scripts to Shell Scripts

The new operator requires shell scripts instead of direct SQL files:

```bash
# Create init scripts from existing SQL files
./charts/clickhouse-operator/scripts/simple-converter.sh

# Review generated scripts in init-scripts/
ls -la init-scripts/

# Create ConfigMap
./init-scripts/create-configmap.sh
```

### 3. Update Umbrella Chart

The umbrella chart now references the new operator:

```yaml
# Chart.yaml
dependencies:
  - name: pmqs
    version: 0.1.0
    repository: "file://charts/pmqs"
  - name: clickhouse-operator
    version: 0.1.0
    repository: "file://charts/clickhouse-operator"
```

### 4. Deploy with Helm

```bash
# Install dependencies
helm dependency update

# Deploy the chart
helm install clickstack . \
  --namespace clickhouse \
  --create-namespace \
  --set clickhouse-operator.clickhouse.initScripts.enabled=true \
  --set clickhouse-operator.clickhouse.initScripts.configMapName=clickhouse-init-scripts
```

## Feature Mapping

| Previous Feature | Operator Implementation |
|----------------|-------------------------|
| Direct SQL scripts | Shell scripts with configmap |
| S3 storage config | Embedded in extraConfig |
| CronJob tasks | Separate CronJob template |
| Service account | Built-in IRSA support |
| Persistence | VolumeClaimTemplates |
| Probes/health checks | Built into operator |

## S3 Storage Configuration

The S3 storage is now configured through ClickHouse XML configuration:

```xml
<storage_configuration>
  <disks>
    <s3_disk>
      <type>s3</type>
      <endpoint>https://s3.amazonaws.com/my-metrics-bucket/</endpoint>
      <access_key_id></access_key_id>
      <secret_access_key></secret_access_key>
      <region>us-east-1</region>
    </s3_disk>
  </disks>
  <policies>
    <s3_policy>
      <volumes>
        <default_volume>
          <disk>s3_disk</disk>
        </default_volume>
      </volumes>
    </s3_policy>
  </policies>
</storage_configuration>
```

**With IRSA**, the access_key_id and secret_access_key are left empty and automatically provided by the service account.

## CronJob Functionality

The parquet converter cronjob is now deployed alongside the operator but remains independent:

```yaml
cronjobs:
  parquetConverter:
    enabled: true
    schedule: "*/10 * * * *"
    env:
      CLICKHOUSE_HOST: "clickhouse-service-name"
      CLICKHOUSE_PORT: "9000"
```

## Access Control

### User Configuration
Users are configured through the ClickHouseInstallation spec:

```yaml
clickhouse:
  users:
    - name: "app_user"
      hostIP: ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
      accessManagement: 1
      grants:
        - "GRANT SHOW ON *.*"
        - "GRANT SELECT ON system.*"
        - "GRANT SELECT ON default.*"
        - "GRANT SELECT,INSERT,CREATE,SHOW ON default.*"
```

### IRSA Policy
The automated IRSA script creates a least-privilege policy with:
- GetObject/PutObject/DeleteObject on specific bucket prefixes
- ListBucket on bucket with prefix restrictions
- Only access to raw/, processed/, and archive/ prefixes

## Migration Validation

### 1. Verify ClickHouse Installation
```bash
kubectl get clickhouseinstallation -n clickhouse
kubectl describe clickhouseinstallation clickhouse-name -n clickhouse
```

### 2. Check Pod Status
```bash
kubectl get pods -n clickhouse -l app=clickhouse
kubectl logs pod-name -n clickhouse
```

### 3. Test S3 Integration
```bash
kubectl exec -it pod-name -n clickhouse -- \
  clickhouse-client --query "SELECT * FROM system.disks"
```

### 4. Verify CronJob
```bash
kubectl get cronjob -n clickhouse
kubectl get jobs -n clickhouse
```

## Troubleshooting

### Common Issues

1. **IRSA Permissions Failing**
   - Verify the service account annotation: `eks.amazonaws.com/role-arn`
   - Check IAM role trust relationship
   - Validate S3 bucket policy

2. **Init Scripts Not Running**
   - Ensure ConfigMap exists: `kubectl get configmap clickhouse-init-scripts`
   - Verify initScripts.enabled=true in values
   - Check pod logs for execution errors

3. **S3 Storage Not Working**
   - Verify S3 bucket exists and is accessible
   - Check ClickHouse logs for connection errors
   - Ensure proper region and endpoint configuration

### Cleanup Old Resources

After successful migration, clean up the old chart:

```bash
helm uninstall old-clickhouse-release -n clickhouse
# Optionally remove the old charts directory
rm -rf charts/clickhouse
```

## Benefits of Migration

1. **Operator Management**: Automatic pod recovery, configuration updates
2. **Built-in Features**: Health checks, rolling updates, scaling
3. **Community Support**: Active development and best practices
4. **Simplified Operations**: Less custom code to maintain
5. **Enhanced Monitoring**: Better observability and metrics

## Support

- **Altinity Operator Docs**: https://docs.altinity.com/
- **ClickHouse Documentation**: https://clickhouse.com/docs
- **GitHub Issues**: https://github.com/Altinity/clickhouse-operator
