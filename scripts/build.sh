#!/bin/bash
set -e

echo "Building Docker images..."

# Build Product Metrics
echo "Building product-metrics..."
docker build -t my-registry/product-metrics:latest ./mock-src/product-metrics

# Build Parquet Converter
echo "Building parquet-converter..."
docker build -t my-registry/parquet-converter:latest ./mock-src/parquet-converter

echo "Images built successfully."

# If running in Kind/Minikube, we might need to load them.
# Assuming standard Docker environment for now.
if command -v kind &> /dev/null; then
    echo "Detected Kind, loading images..."
    kind load docker-image my-registry/product-metrics:latest
    kind load docker-image my-registry/parquet-converter:latest
elif command -v minikube &> /dev/null; then
    echo "Detected Minikube, loading images..."
    minikube image load my-registry/product-metrics:latest
    minikube image load my-registry/parquet-converter:latest
fi
