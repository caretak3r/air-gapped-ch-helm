#!/bin/bash

# SQL to Shell Script Converter for ClickHouse Operator Migration
# This script converts SQL files to shell scripts compatible with Altinity ClickHouse operator

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INPUT_DIR="$SCRIPT_DIR/sql-scripts"
OUTPUT_DIR="$SCRIPT_DIR/init-scripts"

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Function to convert SQL file to shell script
convert_sql_to_shell() {
    local sql_file="$1"
    local base_name=$(basename "$sql_file" .sql)
    local shell_file="$OUTPUT_DIR/${base_name}.sh"
    
    echo "Converting $sql_file to $shell_file"
    
    # Create shell script header
    cat > "$shell_file" << 'EOF'
#!/bin/bash
set -e

# Auto-generated shell script for ClickHouse init
# Converted from SQL by sql-to-shell-converter.sh

# Wait for ClickHouse to be ready
echo "Waiting for ClickHouse to be ready..."
until clickhouse-client --query "SELECT 1" >/dev/null 2>&1; do
    echo "ClickHouse is not ready yet. Waiting..."
    sleep 2
done

echo "ClickHouse is ready. Executing SQL statements..."

EOF
    
    # Add SQL content with proper escaping
    echo 'clickhouse client -n <<-'EOSQL' >> "$shell_file"
    cat "$sql_file" >> "$shell_file"
    echo 'EOSQL' >> "$shell_file"
    
    # Add success message
    echo "" >> "$shell_file"
    echo 'echo "SQL statements executed successfully."' >> "$shell_file"
    
    # Make the script executable
    chmod +x "$shell_file"
}

# Function to create example init scripts
create_example_scripts() {
    echo "Creating example init scripts..."
    
    # Example: Create database
    cat > "$OUTPUT_DIR/01-create-database.sh" << 'EOF'
#!/bin/bash
set -e

echo "Creating default database..."

clickhouse client -n <<-EOSQL
  CREATE DATABASE IF NOT EXISTS metrics_ingested;
EOSQL

echo "Database created successfully."
EOF
    
    # Example: Create tables
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
  
  -- Create materialized view for processed events
  CREATE MATERIALIZED VIEW IF NOT EXISTS metrics_ingested.processed_events
  ENGINE = MergeTree()
  PARTITION BY toYYYYMM(timestamp)
  ORDER BY (event_type, timestamp, user_id)
  AS SELECT *
  FROM metrics_ingested.events
  WHERE processed = true;
EOSQL

echo "Tables created successfully."
EOF
    
    # Example: Create S3 integration functions
    cat > "$OUTPUT_DIR/03-s3-integration.sh" << 'EOF'
#!/bin/bash
set -e

echo "Setting up S3 integration..."

clickhouse client -n <<-EOSQL
  -- Create S3 table function for external data access
  CREATE TABLE IF NOT EXISTS s3_raw_metrics
  ENGINE = S3(
    'https://s3.amazonaws.com/raw-metrics/',
    'parquet',
    'access_key_id',
    'secret_access_key'
  );
  
  -- Create table function for processed data
  CREATE TABLE IF NOT EXISTS s3_processed_metrics
  ENGINE = S3(
    'https://s3.amazonaws.com/processed-metrics/',
    'parquet',
    'access_key_id', 
    'secret_access_key'
  );
EOSQL

echo "S3 integration configured."
EOF
    
    # Make all scripts executable
    chmod +x "$OUTPUT_DIR"/*.sh
    
    echo "Example init scripts created in $OUTPUT_DIR"
}

# Function to create ConfigMap from init scripts
create_configmap_script() {
    echo "#!/bin/bash" > "$OUTPUT_DIR/create-configmap.sh"
    echo "# Script to create ConfigMap from init scripts" >> "$OUTPUT_DIR/create-configmap.sh"
    echo "" >> "$OUTPUT_DIR/create-configmap.sh"
    echo "kubectl create configmap clickhouse-init-scripts \\" >> "$OUTPUT_DIR/create-configmap.sh"
    echo "  --from-file=$OUTPUT_DIR/01-create-database.sh \\" >> "$OUTPUT_DIR/create-configmap.sh"
    echo "  --from-file=$OUTPUT_DIR/02-create-tables.sh \\" >> "$OUTPUT_DIR/create-configmap.sh"
    echo "  --from-file=$OUTPUT_DIR/03-s3-integration.sh \\" >> "$OUTPUT_DIR/create-configmap.sh"
    echo "  --namespace=\${NAMESPACE:-default}" >> "$OUTPUT_DIR/create-configmap.sh"
    echo "" >> "$OUTPUT_DIR/create-configmap.sh"
    echo "echo \"ConfigMap created successfully.\"" >> "$OUTPUT_DIR/create-configmap.sh"
    
    chmod +x "$OUTPUT_DIR/create-configmap.sh"
}

# Main execution
main() {
    echo "SQL to Shell Script Converter for ClickHouse Operator Migration"
    echo "============================================================="
    
    # Create init scripts directory
    mkdir -p "$OUTPUT_DIR"
    
    # Create input directory if it doesn't exist
    mkdir -p "$INPUT_DIR"
    
    # Convert existing SQL files if they exist
    if [ -d "$INPUT_DIR" ] && [ "$(ls -A $INPUT_DIR)" ]; then
        echo "Found SQL files to convert..."
        for sql_file in "$INPUT_DIR"/*.sql; do
            if [ -f "$sql_file" ]; then
                convert_sql_to_shell "$sql_file"
            fi
        done
    else
        echo "No SQL files found. Creating example scripts..."
        create_example_scripts
    fi
    
    # Create ConfigMap creation script
    create_configmap_script
    
    echo ""
    echo "Conversion completed!"
    echo "Init scripts are available in: $OUTPUT_DIR"
    echo ""
    echo "Next steps:"
    echo "1. Review and customize the scripts in $OUTPUT_DIR"
    echo "2. Run: $OUTPUT_DIR/create-configmap.sh to create the ConfigMap"
    echo "3. Enable initScripts in your values.yaml:"
    echo "   clickhouse:"
    echo "     initScripts:"
    echo "       enabled: true"
    echo "       configMapName: clickhouse-init-scripts"
}

# Run main function
main
