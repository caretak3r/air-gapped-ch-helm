#!/bin/bash
kubectl create configmap clickhouse-init-scripts \
  --from-file=01-create-database.sh \
  --from-file=02-create-tables.sh \
  --from-file=03-s3-integration.sh \
  --namespace=${NAMESPACE:-default}
echo "ConfigMap created successfully."
