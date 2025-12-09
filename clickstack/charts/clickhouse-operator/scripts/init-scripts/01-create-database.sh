#!/bin/bash
set -e
echo "Creating default database..."
clickhouse client -n <<-EOSQL
  CREATE DATABASE IF NOT EXISTS metrics_ingested;
EOSQL
echo "Database created successfully."
