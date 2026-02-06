# Quick Start Guide

Get DuckLake running in 5 minutes!

## Installation

```bash
# Download
git clone https://github.com/lmangani/ducklake-oracle.git
cd ducklake-oracle

# Install (requires sudo)
sudo ./install.sh
```

That's it! DuckLake is now installed.

## First Steps

### 1. Start DuckLake

```bash
ducklake-service start
```

You'll see a DuckDB prompt with DuckLake ready to use.

### 2. Try Some Queries

```sql
-- Check storage configuration
SELECT * FROM storage_info();

-- List existing tables
SELECT * FROM list_tables();

-- Create a table from sample data
CREATE TABLE test AS 
SELECT 1 as id, 'Alice' as name, 30 as age
UNION ALL
SELECT 2 as id, 'Bob' as name, 25 as age;

-- Query it
SELECT * FROM test;

-- Save to Parquet
COPY test TO '/var/lib/ducklake/data/test.parquet' (FORMAT PARQUET);
```

### 3. Load Real Data

```sql
-- From CSV file
CREATE TABLE users AS 
SELECT * FROM read_csv_auto('/path/to/users.csv');

-- From URL
CREATE TABLE flights AS 
SELECT * FROM 'https://duckdb.org/data/flights.csv' LIMIT 1000;

-- From Parquet
CREATE TABLE events AS 
SELECT * FROM read_parquet('events.parquet');

-- Query
SELECT * FROM flights LIMIT 10;
```

## Common Tasks

### Check Status

```bash
ducklake-service status
```

### Run Query from Shell

```bash
ducklake-service query "SELECT COUNT(*) FROM metadata.tables;"
```

### Configure S3 Storage

Edit `/etc/ducklake.conf`:

```bash
STORAGE_TYPE=s3
S3_ENDPOINT=https://s3.amazonaws.com
S3_REGION=us-east-1
S3_BUCKET=my-bucket
S3_ACCESS_KEY=your-key
S3_SECRET_KEY=your-secret
S3_USE_SSL=true
```

Restart:

```bash
sudo systemctl restart ducklake
```

## What's Next?

- Read the full [README.md](README.md) for detailed documentation
- Explore [DuckDB documentation](https://duckdb.org/docs/)
- Configure systemd for automatic startup: `sudo systemctl enable ducklake`

## Need Help?

```bash
# Installation help
./install.sh --help

# Service help
ducklake-service help

# DuckDB help
duckdb -help
```

## Quick Reference

| Task | Command |
|------|---------|
| Install | `sudo ./install.sh` |
| Start session | `ducklake-service start` |
| Check status | `ducklake-service status` |
| Run query | `ducklake-service query 'SQL'` |
| Config file | `/etc/ducklake.conf` |
| Data location | `/var/lib/ducklake/data` |
| Metadata DB | `/var/lib/ducklake/metadata/ducklake.db` |

---

Happy querying! 🦆
