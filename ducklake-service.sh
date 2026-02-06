#!/bin/bash
# DuckLake Service Script
# Manages the DuckLake service

set -e

# Load configuration
if [ -f /etc/ducklake.conf ]; then
    . /etc/ducklake.conf
fi

# Default values if not set in config
DATA_PATH="${DATA_PATH:-/var/lib/ducklake}"
METADATA_DB="${METADATA_DB:-$DATA_PATH/metadata/ducklake.db}"
STORAGE_TYPE="${STORAGE_TYPE:-local}"
LOCAL_DATA_PATH="${LOCAL_DATA_PATH:-$DATA_PATH/data}"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show status
show_status() {
    log_info "DuckLake Service Status"
    log_info "========================"
    log_info "Configuration file: /etc/ducklake.conf"
    log_info "Data path: $DATA_PATH"
    log_info "Metadata DB: $METADATA_DB"
    log_info "Storage type: $STORAGE_TYPE"
    
    if [ "$STORAGE_TYPE" = "local" ]; then
        log_info "Local data path: $LOCAL_DATA_PATH"
        if [ -d "$LOCAL_DATA_PATH" ]; then
            log_info "Data directory exists: YES"
            du -sh "$LOCAL_DATA_PATH" 2>/dev/null | awk '{print "  Size: " $1}'
        else
            log_warn "Data directory does not exist"
        fi
    elif [ "$STORAGE_TYPE" = "s3" ]; then
        log_info "S3 endpoint: ${S3_ENDPOINT:-not set}"
        log_info "S3 bucket: ${S3_BUCKET:-not set}"
        log_info "S3 region: ${S3_REGION:-not set}"
    fi
    
    if [ -f "$METADATA_DB" ]; then
        log_info "Metadata database exists: YES"
        local size
        size=$(du -sh "$METADATA_DB" 2>/dev/null | awk '{print $1}')
        log_info "  Size: $size"
        local tables
        tables=$(sqlite3 "$METADATA_DB" "SELECT COUNT(*) FROM tables;" 2>/dev/null || echo "0")
        log_info "  Tables: $tables"
    else
        log_warn "Metadata database does not exist"
    fi
}

# Function to start interactive DuckDB session
start_session() {
    log_info "Starting DuckDB session..."
    log_info "Storage type: $STORAGE_TYPE"
    
    # Create init SQL for this session
    INIT_SQL="/tmp/ducklake-init-$$.sql"
    cat > "$INIT_SQL" <<EOF
-- Load extensions
INSTALL sqlite;
LOAD sqlite;

-- Attach SQLite metadata database
ATTACH '$METADATA_DB' AS metadata (TYPE sqlite, READ_ONLY false);

-- Set data path based on storage type
.mode box
SELECT 'DuckLake Ready!' as status;
SELECT 'Storage: $STORAGE_TYPE' as info;
EOF

    if [ "$STORAGE_TYPE" = "s3" ]; then
        cat >> "$INIT_SQL" <<EOF
-- Configure S3 storage
SET s3_endpoint='$S3_ENDPOINT';
SET s3_region='$S3_REGION';
SET s3_access_key_id='$S3_ACCESS_KEY';
SET s3_secret_access_key='$S3_SECRET_KEY';
SET s3_use_ssl=$S3_USE_SSL;
SELECT 'S3 Bucket: $S3_BUCKET' as info;
EOF
    else
        cat >> "$INIT_SQL" <<EOF
SELECT 'Data path: $LOCAL_DATA_PATH' as info;
EOF
    fi

    cat >> "$INIT_SQL" <<EOF

-- Helper: List all tables
CREATE OR REPLACE MACRO list_tables() AS TABLE 
  SELECT name, data_path, created_at FROM metadata.tables ORDER BY name;

-- Helper: Show storage info
CREATE OR REPLACE MACRO storage_info() AS TABLE
  SELECT 
    '$STORAGE_TYPE' as storage_type,
    '$LOCAL_DATA_PATH' as local_path,
    '${S3_BUCKET:-not configured}' as s3_bucket;

.print
.print Available commands:
.print   list_tables()      - List all tables
.print   storage_info()     - Show storage configuration
.print   .help              - Show DuckDB help
.print
EOF

    # Start DuckDB with init script
    duckdb -init "$INIT_SQL"
    
    # Cleanup
    rm -f "$INIT_SQL"
}

# Function to run a query
run_query() {
    local query="$1"
    duckdb "$METADATA_DB" "$query"
}

# Function to create a table
create_table() {
    local table_name="$1"
    local source_path="$2"
    
    log_info "Creating table: $table_name from $source_path"
    
    # Determine target path based on storage type
    local data_path
    if [ "$STORAGE_TYPE" = "s3" ]; then
        data_path="s3://$S3_BUCKET/$table_name.parquet"
    else
        data_path="$LOCAL_DATA_PATH/$table_name.parquet"
    fi
    
    log_info "Data will be stored at: $data_path"
    
    # Insert into metadata
    sqlite3 "$METADATA_DB" "
    INSERT INTO tables (catalog_id, name, data_path)
    SELECT id, '$table_name', '$data_path'
    FROM catalogs WHERE name = 'main';
    "
    
    log_info "Table metadata created successfully"
}

# Main command handling
case "${1:-help}" in
    start)
        start_session
        ;;
    status)
        show_status
        ;;
    query)
        if [ -z "$2" ]; then
            log_error "Usage: $0 query 'SQL QUERY'"
            exit 1
        fi
        run_query "$2"
        ;;
    create-table)
        if [ -z "$2" ] || [ -z "$3" ]; then
            log_error "Usage: $0 create-table TABLE_NAME SOURCE_PATH"
            exit 1
        fi
        create_table "$2" "$3"
        ;;
    help|--help|-h)
        echo "DuckLake Service Script"
        echo ""
        echo "Usage: $0 COMMAND [OPTIONS]"
        echo ""
        echo "Commands:"
        echo "  start              Start interactive DuckDB session"
        echo "  status             Show service status and configuration"
        echo "  query 'SQL'        Run a SQL query"
        echo "  create-table NAME SOURCE"
        echo "                     Create a new table with metadata"
        echo "  help               Show this help message"
        echo ""
        echo "Examples:"
        echo "  $0 start"
        echo "  $0 status"
        echo "  $0 query 'SELECT * FROM metadata.tables;'"
        echo "  $0 create-table users /path/to/users.csv"
        echo ""
        ;;
    *)
        log_error "Unknown command: $1"
        echo "Run '$0 help' for usage information"
        exit 1
        ;;
esac
