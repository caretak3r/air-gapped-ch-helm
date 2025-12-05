#!/bin/bash
set -e

RELEASE_NAME="control-plane"
NAMESPACE="default"
CHART_PATH="./control-plane-umbrella"

echo "Deploying $RELEASE_NAME..."

# Install or Upgrade
helm upgrade --install $RELEASE_NAME $CHART_PATH \
    --namespace $NAMESPACE \
    --create-namespace \
    --set global.environment=local

echo "Deployment triggered. Checking status..."
kubectl rollout status deployment/product-metrics -n $NAMESPACE --timeout=60s
