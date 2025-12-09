#!/bin/bash
set -e
echo "Setting up S3 integration..."
clickhouse client -n <<-EOSQL
  -- Create S3 storage configuration if not already in config
  CREATE TABLE IF NOT EXISTS metrics_ingested.example_s3_table
  ENGINE = S3('https://s3.amazonaws.com/my-metrics-bucket/example/', 'CSV');
EOSQL
echo "S3 integration configured."
