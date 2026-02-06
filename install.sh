#!/bin/bash
# DuckLake Installation Script
# Simple installation of DuckLake with SQLite metadata storage
# 
# Usage: ./install.sh [--data-path /path/to/data]

set -e

# Default configuration
DATA_PATH="${DATA_PATH:-/var/lib/ducklake}"
DUCKLAKE_USER="${DUCKLAKE_USER:-ducklake}"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --data-path)
            DATA_PATH="$2"
            shift 2
            ;;
        --user)
            DUCKLAKE_USER="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --data-path PATH    Path for DuckLake data storage (default: /var/lib/ducklake)"
            echo "  --user USER         User to run DuckLake service (default: ducklake)"
            echo "  --help              Show this help message"
            echo ""
            echo "Environment variables:"
            echo "  DATA_PATH           Same as --data-path"
            echo "  DUCKLAKE_USER       Same as --user"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

log_info "Starting DuckLake installation..."
log_info "Data path: $DATA_PATH"
log_info "Service user: $DUCKLAKE_USER"

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    OS_VERSION=$VERSION_ID
else
    log_error "Cannot detect OS. /etc/os-release not found."
    exit 1
fi

log_info "Detected OS: $OS $OS_VERSION"

# Install DuckDB
log_info "Installing DuckDB..."
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
    DUCKDB_ARCH="amd64"
elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
    DUCKDB_ARCH="aarch64"
else
    log_error "Unsupported architecture: $ARCH"
    exit 1
fi

DUCKDB_VERSION="v1.3.0"
DUCKDB_URL="https://github.com/duckdb/duckdb/releases/download/${DUCKDB_VERSION}/duckdb_cli-linux-${DUCKDB_ARCH}.zip"

log_info "Downloading DuckDB from $DUCKDB_URL"
cd /tmp
curl -L -o duckdb.zip "$DUCKDB_URL"
unzip -o duckdb.zip
sudo mv duckdb "$INSTALL_DIR/duckdb"
sudo chmod +x "$INSTALL_DIR/duckdb"
rm duckdb.zip

log_info "DuckDB installed at $INSTALL_DIR/duckdb"
duckdb --version

# Install SQLite (usually pre-installed, but ensure it's available)
log_info "Checking SQLite..."
if command -v sqlite3 &> /dev/null; then
    log_info "SQLite is already installed: $(sqlite3 --version)"
else
    log_info "Installing SQLite..."
    case $OS in
        ubuntu|debian)
            sudo apt-get update
            sudo apt-get install -y sqlite3
            ;;
        ol|rhel|centos|rocky|almalinux)
            sudo dnf install -y sqlite || sudo yum install -y sqlite
            ;;
        *)
            log_error "Unsupported OS: $OS"
            exit 1
            ;;
    esac
fi

# Create ducklake user if it doesn't exist
if ! id "$DUCKLAKE_USER" &>/dev/null; then
    log_info "Creating user: $DUCKLAKE_USER"
    sudo useradd -r -s /bin/bash -d "$DATA_PATH" -m "$DUCKLAKE_USER"
else
    log_info "User $DUCKLAKE_USER already exists"
fi

# Create data directory
log_info "Creating data directory: $DATA_PATH"
sudo mkdir -p "$DATA_PATH"
sudo mkdir -p "$DATA_PATH/metadata"
sudo mkdir -p "$DATA_PATH/data"
sudo chown -R "$DUCKLAKE_USER:$DUCKLAKE_USER" "$DATA_PATH"
sudo chmod 755 "$DATA_PATH"

# Create SQLite database for metadata
log_info "Initializing SQLite metadata database..."
sudo -u "$DUCKLAKE_USER" sqlite3 "$DATA_PATH/metadata/ducklake.db" "
CREATE TABLE IF NOT EXISTS catalogs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS tables (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    catalog_id INTEGER NOT NULL,
    name TEXT NOT NULL,
    schema_json TEXT,
    data_path TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (catalog_id) REFERENCES catalogs(id),
    UNIQUE(catalog_id, name)
);

-- Insert default catalog
INSERT OR IGNORE INTO catalogs (name) VALUES ('main');
"

log_info "SQLite metadata database created at $DATA_PATH/metadata/ducklake.db"

# Copy service script
log_info "Installing DuckLake service script..."
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
sudo cp "$SCRIPT_DIR/ducklake-service.sh" "$INSTALL_DIR/ducklake-service"
sudo chmod +x "$INSTALL_DIR/ducklake-service"

# Create systemd service (optional)
if command -v systemctl &> /dev/null; then
    log_info "Creating systemd service..."
    sudo tee /etc/systemd/system/ducklake.service > /dev/null <<EOF
[Unit]
Description=DuckLake Service
After=network.target

[Service]
Type=simple
User=$DUCKLAKE_USER
WorkingDirectory=$DATA_PATH
Environment="DATA_PATH=$DATA_PATH"
ExecStart=$INSTALL_DIR/ducklake-service start
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    log_info "Systemd service created. Enable it with: sudo systemctl enable --now ducklake"
else
    log_warn "systemd not found. Service must be run manually."
fi

# Create configuration file
log_info "Creating configuration file..."
sudo tee /etc/ducklake.conf > /dev/null <<EOF
# DuckLake Configuration
# Local storage (default)
DATA_PATH=$DATA_PATH
METADATA_DB=$DATA_PATH/metadata/ducklake.db
STORAGE_TYPE=local
LOCAL_DATA_PATH=$DATA_PATH/data

# Optional: S3-compatible object storage
# Uncomment and configure to use S3 instead of local storage
# STORAGE_TYPE=s3
# S3_ENDPOINT=https://s3.amazonaws.com
# S3_REGION=us-east-1
# S3_BUCKET=ducklake-data
# S3_ACCESS_KEY=your-access-key
# S3_SECRET_KEY=your-secret-key
# S3_USE_SSL=true
EOF

sudo chmod 644 /etc/ducklake.conf

log_info ""
log_info "============================================"
log_info "DuckLake installation complete!"
log_info "============================================"
log_info ""
log_info "Configuration file: /etc/ducklake.conf"
log_info "Data directory: $DATA_PATH"
log_info "Metadata database: $DATA_PATH/metadata/ducklake.db"
log_info ""
log_info "Next steps:"
log_info "1. Edit /etc/ducklake.conf to configure storage options"
log_info "2. Start the service:"
log_info "   - With systemd: sudo systemctl enable --now ducklake"
log_info "   - Manually: sudo -u $DUCKLAKE_USER $INSTALL_DIR/ducklake-service start"
log_info "3. Connect with DuckDB:"
log_info "   duckdb $DATA_PATH/metadata/ducklake.db"
log_info ""
log_info "For S3 storage, edit /etc/ducklake.conf and uncomment S3 settings"
log_info ""
