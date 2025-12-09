#!/bin/bash
set -e
echo "Creating tables..."
clickhouse client -n <<-EOSQL
  CREATE TABLE IF NOT EXISTS metrics_ingested.events (
    timestamp DateTime64(3),
    event_type String,
    user_id String,
    properties String,
    processed Boolean DEFAULT false
  ) ENGINE = MergeTree()
  PARTITION BY toYYYYMM(timestamp)
  ORDER BY (event_type, timestamp, user_id)
  SETTINGS storage_policy = 's3_policy';
EOSQL
echo "Tables created successfully."
