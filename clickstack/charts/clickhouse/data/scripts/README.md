# ClickHouse SQL Scripts

This directory contains SQL scripts that will be executed during ClickHouse pod termination in the preStop lifecycle hook.

## Adding Your Own Scripts

1. **Create your SQL files** in this directory with `.sql` extension
2. **Configure the scripts** in `values.yaml`:
   ```yaml
   scripts:
     enabled: true
     files:
       - "your-script.sql"
       - "another-script.sql"
     delayBetween: 3
   ```

## Script Execution

- Scripts execute in the order listed in `scripts.files`
- Each script runs with `clickhouse-client --queries-file [script]`
- Scripts execute after standard ClickHouse shutdown commands
- Optional delay between script executions
- Log output goes to pod logs

## Notes

- Scripts should be idempotent (safe to run multiple times)
- Use standard ClickHouse SQL syntax
- Scripts have read-only access to the file system
- Scripts can reference ClickHouse system tables and metadata

## Example Script Structure

```sql
-- Example customization script
-- This will execute during pod termination

CREATE DATABASE IF NOT EXISTS my_custom_db;
CREATE TABLE IF NOT EXISTS my_custom_db.my_table (
    id UInt64,
    name String,
    created_at DateTime DEFAULT now()
) ENGINE = MergeTree()
ORDER BY id;
```

Files without `.sql` extension or files that don't exist will be safely skipped during execution.
