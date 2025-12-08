#!/bin/bash
set -e

NAMESPACE="default"

echo "Testing Product Metrics Service..."
# Start port forward in background
kubectl port-forward -n $NAMESPACE service/control-plane-product-metrics-query-service 8080:8080 > /dev/null 2>&1 &
PID_PM=$!
sleep 2
# Check health
if curl -s http://localhost:8080/health | grep "OK"; then
    echo "Product Metrics Service is HEALTHY"
else
    echo "Product Metrics Service FAIL"
    kill $PID_PM
    exit 1
fi
kill $PID_PM

echo "Testing ClickHouse Compute..."
kubectl port-forward -n $NAMESPACE service/control-plane-clickhouse-compute 8123:8123 > /dev/null 2>&1 &
PID_CH=$!
sleep 2
# Check ping
if curl -s http://localhost:8123/ping | grep "Ok"; then
    echo "ClickHouse Compute is HEALTHY"
else
    echo "ClickHouse Compute FAIL"
    kill $PID_CH
    exit 1
fi
kill $PID_CH

echo "All tests passed."
