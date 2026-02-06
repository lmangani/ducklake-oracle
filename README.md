# DuckLake - Simple Local Installation

A super simple script to install [DuckLake](https://ducklake.select/) with SQLite metadata storage on any Linux instance. Works with local storage by default, with optional S3-compatible object storage support.

> **Note:** The repository name "ducklake-oracle" is historical. This installation works on **any Linux distribution** (Ubuntu, Debian, RHEL, Oracle Linux, etc.), not just Oracle Cloud.

## What You Get

- **DuckDB** - Modern analytical query engine
- **SQLite** - Lightweight metadata catalog
- **Local Storage** - Store data files locally (default)
- **Optional S3** - Use S3-compatible object storage if needed
- **Simple Service** - Easy-to-use service script

## Quick Start

### Prerequisites

- Linux instance (x86_64 or ARM64/aarch64)
- Root or sudo access
- Internet connection for downloading DuckDB

### Installation

```bash
# Clone repository
git clone https://github.com/lmangani/ducklake-oracle.git
cd ducklake-oracle

# Run installation script
sudo ./install.sh
```

The installer will:
1. Download and install DuckDB
2. Ensure SQLite is installed
3. Create a `ducklake` user and data directory
4. Initialize SQLite metadata database
5. Install service script
6. Create systemd service (if available)
7. Create configuration file at `/etc/ducklake.conf`

### Custom Installation Options

```bash
# Install with custom data path
sudo ./install.sh --data-path /mnt/data/ducklake

# Install with custom user
sudo ./install.sh --user myuser

# Or use environment variables
sudo DATA_PATH=/custom/path DUCKLAKE_USER=myuser ./install.sh
```

## Using DuckLake

### Start Interactive Session

```bash
# Start DuckDB session with DuckLake
ducklake-service start

# Or with systemd
sudo systemctl start ducklake
```

Inside the DuckDB session:

```sql
-- List all tables
SELECT * FROM list_tables();

-- Show storage configuration
SELECT * FROM storage_info();

-- Create a table from CSV
CREATE TABLE users AS 
  SELECT * FROM read_csv_auto('/path/to/users.csv');

-- Query data
SELECT * FROM users LIMIT 10;

-- Export to Parquet
COPY users TO '/var/lib/ducklake/data/users.parquet' (FORMAT PARQUET);
```

### Check Status

```bash
ducklake-service status
```

### Run Query from Command Line

```bash
ducklake-service query "SELECT COUNT(*) FROM metadata.tables;"
```

## Storage Configuration

### Local Storage (Default)

Data is stored in `/var/lib/ducklake/data` by default.

**Configuration** (`/etc/ducklake.conf`):
```bash
STORAGE_TYPE=local
LOCAL_DATA_PATH=/var/lib/ducklake/data
```

**Pros:**
- Simple setup
- Fast access
- No additional costs
- No network dependency

**Cons:**
- Limited by local disk space
- Data tied to instance
- Manual backups needed

### S3-Compatible Object Storage (Optional)

To use S3, Oracle Cloud Object Storage, MinIO, or other S3-compatible storage:

**Edit** `/etc/ducklake.conf`:
```bash
STORAGE_TYPE=s3
S3_ENDPOINT=https://s3.amazonaws.com
S3_REGION=us-east-1
S3_BUCKET=my-ducklake-bucket
S3_ACCESS_KEY=your-access-key
S3_SECRET_KEY=your-secret-key
S3_USE_SSL=true
```

**Oracle Cloud Object Storage Example:**
```bash
STORAGE_TYPE=s3
S3_ENDPOINT=https://namespace.compat.objectstorage.us-ashburn-1.oraclecloud.com
S3_REGION=us-ashburn-1
S3_BUCKET=ducklake-data
S3_ACCESS_KEY=your-oci-access-key
S3_SECRET_KEY=your-oci-secret-key
S3_USE_SSL=true
```

**Pros:**
- Decoupled from compute
- Durable storage
- Easy to scale
- Share data across instances

**Cons:**
- Network latency
- Additional cost (after free tier)
- Requires S3 API credentials

## Service Management

### With systemd

```bash
# Enable and start service
sudo systemctl enable --now ducklake

# Check status
sudo systemctl status ducklake

# View logs
sudo journalctl -u ducklake -f

# Stop service
sudo systemctl stop ducklake
```

### Manual Management

```bash
# Start interactive session
ducklake-service start

# Check status
ducklake-service status

# Run query
ducklake-service query "SELECT * FROM list_tables();"
```

## File Locations

- **Configuration**: `/etc/ducklake.conf`
- **Data Directory**: `/var/lib/ducklake` (default)
- **Metadata DB**: `/var/lib/ducklake/metadata/ducklake.db`
- **Local Data**: `/var/lib/ducklake/data`
- **Service Script**: `/usr/local/bin/ducklake-service`
- **DuckDB Binary**: `/usr/local/bin/duckdb`

## Examples

### Load CSV Data

```sql
-- Create table from CSV
CREATE TABLE sales AS 
  SELECT * FROM read_csv_auto('sales.csv');

-- Verify
SELECT COUNT(*) FROM sales;
```

### Load Parquet Data

```sql
-- Read parquet file
CREATE TABLE events AS 
  SELECT * FROM read_parquet('events.parquet');
```

### Query Remote Data

```sql
-- Query CSV from URL
SELECT * FROM read_csv_auto('https://example.com/data.csv') LIMIT 10;

-- Query Parquet from S3
SELECT * FROM read_parquet('s3://my-bucket/data.parquet');
```

### Export Data

```sql
-- Export to Parquet
COPY sales TO '/var/lib/ducklake/data/sales.parquet' (FORMAT PARQUET);

-- Export to CSV
COPY sales TO '/var/lib/ducklake/data/sales.csv' (HEADER, DELIMITER ',');
```

## Backup and Restore

### Backup Metadata

```bash
# Backup SQLite database
sudo cp /var/lib/ducklake/metadata/ducklake.db /backup/ducklake.db.backup

# Or use SQLite backup
sudo sqlite3 /var/lib/ducklake/metadata/ducklake.db ".backup /backup/ducklake.db"
```

### Restore Metadata

```bash
# Restore from backup
sudo cp /backup/ducklake.db.backup /var/lib/ducklake/metadata/ducklake.db
sudo chown ducklake:ducklake /var/lib/ducklake/metadata/ducklake.db
```

### Backup Data

**Local storage:**
```bash
# Backup entire data directory
sudo tar czf /backup/ducklake-data.tar.gz /var/lib/ducklake/data
```

**S3 storage:**
Data is already in S3, just ensure bucket versioning/backup is enabled.

## Uninstall

```bash
# Stop service
sudo systemctl stop ducklake
sudo systemctl disable ducklake

# Remove files
sudo rm -f /usr/local/bin/ducklake-service
sudo rm -f /usr/local/bin/duckdb
sudo rm -f /etc/ducklake.conf
sudo rm -f /etc/systemd/system/ducklake.service

# Remove data (WARNING: This deletes all data!)
sudo rm -rf /var/lib/ducklake

# Remove user
sudo userdel ducklake
```

## Troubleshooting

### DuckDB not found

```bash
# Check if DuckDB is installed
which duckdb

# Verify it's executable
ls -l /usr/local/bin/duckdb

# Check version
duckdb --version
```

### Permission denied

```bash
# Ensure proper permissions
sudo chown -R ducklake:ducklake /var/lib/ducklake
sudo chmod 755 /var/lib/ducklake
```

### SQLite database locked

```bash
# Check for processes using the database
sudo lsof /var/lib/ducklake/metadata/ducklake.db

# Kill if necessary
sudo pkill -u ducklake duckdb
```

### S3 connection errors

```bash
# Test S3 credentials with AWS CLI
aws s3 ls s3://your-bucket --endpoint-url https://your-endpoint

# Check DuckDB S3 settings
ducklake-service query "SELECT current_setting('s3_endpoint');"
```

## Resources

- [DuckDB Documentation](https://duckdb.org/docs/)
- [DuckLake Documentation](https://ducklake.select/)
- [SQLite Documentation](https://www.sqlite.org/docs.html)

## License

MIT

## Support

For issues, please open an issue on GitHub.
