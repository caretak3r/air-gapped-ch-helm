#!/bin/bash

# Simple SQL to Shell Script Converter
set -e

OUTPUT_DIR="init-scripts"
mkdir -p "$OUTPUT_DIR"

echo "Creating example ClickHouse init scripts..."

# Script 1: Create database
cat > "$OUTPUT_DIR/01-create-database.sh" << 'EOF'
#!/bin/bash
set -e
echo "Creating default database..."
clickhouse client -n <<-EOSQL
  CREATE DATABASE IF NOT EXISTS metrics_ingested;
EOSQL
echo "Database created successfully."
EOF

# Script 2: Create tables with S3 storage policy
cat > "$OUTPUT_DIR/02-create-tables.sh" << 'EOF'
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
EOF

# Script 3: S3 integration
cat > "$OUTPUT_DIR/03-s3-integration.sh" << 'EOF'
#!/bin/bash
set -e
echo "Setting up S3 integration..."
clickhouse client -n <<-EOSQL
  -- Create S3 storage configuration if not already in config
  CREATE TABLE IF NOT EXISTS metrics_ingested.example_s3_table
  ENGINE = S3('https://s3.amazonaws.com/my-metrics-bucket/example/', 'CSV');
EOSQL
echo "S3 integration configured."
EOF

# Make scripts executable
chmod +x "$OUTPUT_DIR"/*.sh

# Create ConfigMap creation script
cat > "$OUTPUT_DIR/create-configmap.sh" << 'EOF'
#!/bin/bash
kubectl create configmap clickhouse-init-scripts \
  --from-file=01-create-database.sh \
  --from-file=02-create-tables.sh \
  --from-file=03-s3-integration.sh \
  --namespace=${NAMESPACE:-default}
echo "ConfigMap created successfully."
EOF

chmod +x "$OUTPUT_DIR/create-configmap.sh"

echo "Init scripts created in $OUTPUT_DIR/"
echo "Run: $OUTPUT_DIR/create-configmap.sh to create the ConfigMap"
