# Migration Guide: Hetzner to Oracle Cloud

This guide helps you migrate your DuckLake deployment from Hetzner Cloud to Oracle Cloud Infrastructure (OCI).

## Pre-Migration Checklist

- [ ] Oracle Cloud account with free tier activated
- [ ] OCI API keys generated
- [ ] Customer Secret Keys created for Object Storage
- [ ] Backup of PostgreSQL database
- [ ] Export of S3 data locations

## Step 1: Backup Your Data

### Backup PostgreSQL Metadata

```bash
# SSH into your Hetzner server
ssh root@<hetzner-ip>

# Create PostgreSQL backup
sudo -u postgres pg_dump ducklake_catalog > /tmp/ducklake_backup.sql

# Download the backup
scp root@<hetzner-ip>:/tmp/ducklake_backup.sql ./ducklake_backup.sql
```

### List Your S3 Data

```bash
# List all objects in your bucket
aws s3 ls s3://your-bucket-name --recursive --endpoint-url https://nbg1.your-objectstorage.com

# Or create a manifest
aws s3 ls s3://your-bucket-name --recursive --endpoint-url https://nbg1.your-objectstorage.com > s3_manifest.txt
```

## Step 2: Setup Oracle Cloud

Follow the setup instructions in the main README.md:

1. Configure OCI credentials
2. Set up `.env` file with Oracle Cloud variables
3. Run `make init` to initialize Terraform
4. Run `make terraform-apply` to create infrastructure

## Step 3: Migrate Object Storage Data

### Option A: Direct Copy (Fastest)

```bash
# Install rclone
curl https://rclone.org/install.sh | sudo bash

# Configure Hetzner source
rclone config create hetzner s3 \
    provider Scaleway \
    endpoint nbg1.your-objectstorage.com \
    access_key_id YOUR_HETZNER_KEY \
    secret_access_key YOUR_HETZNER_SECRET

# Configure Oracle Cloud destination
rclone config create oracle s3 \
    provider Other \
    endpoint YOUR_NAMESPACE.compat.objectstorage.us-ashburn-1.oraclecloud.com \
    access_key_id YOUR_ORACLE_KEY \
    secret_access_key YOUR_ORACLE_SECRET

# Copy data
rclone copy hetzner:your-bucket oracle:ducklake-bucket --progress
```

### Option B: Using AWS CLI

```bash
# Sync from Hetzner to local
aws s3 sync s3://hetzner-bucket ./local-backup \
    --endpoint-url https://nbg1.your-objectstorage.com

# Sync from local to Oracle Cloud
aws s3 sync ./local-backup s3://oracle-bucket \
    --endpoint-url https://YOUR_NAMESPACE.compat.objectstorage.us-ashburn-1.oraclecloud.com
```

## Step 4: Restore PostgreSQL Database

```bash
# Wait for deployment to complete
make deploy

# Copy backup to Oracle Cloud instance
scp -i ~/.ssh/id_rsa ducklake_backup.sql opc@<oracle-ip>:/tmp/

# SSH into Oracle Cloud instance
ssh -i ~/.ssh/id_rsa opc@<oracle-ip>

# Restore the database
sudo -u postgres psql ducklake_catalog < /tmp/ducklake_backup.sql

# Verify restoration
sudo -u postgres psql ducklake_catalog -c "SELECT COUNT(*) FROM pg_tables WHERE schemaname = 'public';"
```

## Step 5: Update DuckDB Configuration

Update your `.env` file with new values:

```bash
# Old (Hetzner)
POSTGRES_HOST="<hetzner-ip>"
S3_ENDPOINT="nbg1.your-objectstorage.com"
S3_BUCKET_NAME="hetzner-bucket"

# New (Oracle Cloud)
POSTGRES_HOST="<oracle-ip>"
S3_ENDPOINT="namespace.compat.objectstorage.us-ashburn-1.oraclecloud.com"
S3_BUCKET_NAME="ducklake-bucket"
```

Reload environment and test:

```bash
set -a && source .env && set +a
make duckdb
```

## Step 6: Verify Migration

Run these queries in DuckDB to verify everything works:

```sql
-- Check tables are accessible
SHOW TABLES;

-- Verify data
SELECT COUNT(*) FROM your_table;

-- Test S3 access
SELECT * FROM 's3://ducklake-bucket/test.parquet' LIMIT 10;

-- Check metadata
SELECT table_name, row_count FROM duckdb_tables();
```

## Step 7: Update Applications

If you have applications connecting to your DuckLake:

1. Update connection strings to new Oracle Cloud IP
2. Update S3 endpoints in application configuration
3. Test all queries and data pipelines
4. Update monitoring dashboards

## Step 8: Cleanup Hetzner Resources

⚠️ **Only do this after verifying everything works on Oracle Cloud!**

```bash
# Destroy Hetzner infrastructure
# (In your old Hetzner directory)
cd terraform
tofu destroy

# Or manually delete from Hetzner Console:
# 1. Server
# 2. Primary IP
# 3. SSH Key
# 4. Object Storage bucket
```

## Troubleshooting Migration Issues

### PostgreSQL restore fails

```bash
# Check PostgreSQL is running
sudo systemctl status postgresql-16

# Check permissions
sudo -u postgres psql -c "\du"

# Re-create database if needed
sudo -u postgres dropdb ducklake_catalog
sudo -u postgres createdb -O ducklake ducklake_catalog
sudo -u postgres psql ducklake_catalog < /tmp/ducklake_backup.sql
```

### S3 data not accessible

```bash
# Test S3 credentials
aws s3 ls s3://ducklake-bucket \
    --endpoint-url https://namespace.compat.objectstorage.us-ashburn-1.oraclecloud.com

# Verify bucket policy
# In OCI Console: Object Storage → Bucket → Edit Visibility
```

### Connection refused from DuckDB

```bash
# Check firewall on Oracle Cloud instance
ssh -i ~/.ssh/id_rsa opc@<oracle-ip>
sudo firewall-cmd --list-all

# Verify PostgreSQL is listening
sudo netstat -tlnp | grep 5432

# Check pg_hba.conf
sudo cat /var/lib/pgsql/16/data/pg_hba.conf | grep ducklake
```

## Performance Comparison

After migration, you might notice:

| Metric | Hetzner (cx33) | Oracle Cloud (2 OCPU) |
|--------|----------------|----------------------|
| CPU | 4x x86_64 | 2x ARM64 |
| RAM | 8 GB | 12 GB |
| Storage | 80 GB NVMe | 50 GB boot + 50 GB block |
| Network | ~20 Gbps | ~1-2 Gbps |
| Query Performance | Baseline | 70-90% (ARM64) |

**Note:** ARM64 may be slightly slower for some workloads but has more memory available.

## Cost Comparison

| Service | Hetzner | Oracle Cloud Free Tier |
|---------|---------|------------------------|
| Compute | €5.49/mo | $0 |
| Storage | Included | $0 (within limits) |
| Object Storage | €3.50/TB | $0.026/GB (after 10 GB) |
| **Total (1TB data)** | **€9/mo (~$10)** | **~$25/mo** or **$0** (under 10 GB) |

For small to medium datasets (<100 GB), Oracle Cloud can be significantly cheaper or free.

## Rollback Plan

If you need to rollback:

1. Keep Hetzner infrastructure running during migration
2. Maintain backups of both systems
3. Test thoroughly before destroying Hetzner resources
4. Keep DNS/connection strings pointing to Hetzner until verified

## Post-Migration Optimization

### Enable Block Volume for PostgreSQL

```bash
# Format and mount block volume
sudo mkfs.ext4 /dev/sdb
sudo mkdir -p /mnt/pgsql-data
sudo mount /dev/sdb /mnt/pgsql-data

# Move PostgreSQL data
sudo systemctl stop postgresql-16
sudo mv /var/lib/pgsql/16/data /mnt/pgsql-data/
sudo ln -s /mnt/pgsql-data/data /var/lib/pgsql/16/data
sudo chown -R postgres:postgres /mnt/pgsql-data
sudo systemctl start postgresql-16

# Add to fstab
echo '/dev/sdb /mnt/pgsql-data ext4 defaults 0 0' | sudo tee -a /etc/fstab
```

### Tune PostgreSQL for ARM64

```bash
# Edit PostgreSQL config
sudo vi /var/lib/pgsql/16/data/postgresql.conf

# Recommended settings for 12 GB RAM:
shared_buffers = 3GB
effective_cache_size = 9GB
maintenance_work_mem = 1GB
checkpoint_completion_target = 0.9
wal_buffers = 16MB
default_statistics_target = 100
random_page_cost = 1.1
effective_io_concurrency = 200
work_mem = 32MB
min_wal_size = 1GB
max_wal_size = 4GB
max_worker_processes = 2
max_parallel_workers_per_gather = 1
max_parallel_workers = 2
```

## Support

For migration issues:
- Check the main [README.md](README.md) troubleshooting section
- Review [ORACLE_CLOUD_SETUP.md](ORACLE_CLOUD_SETUP.md) for configuration details
- Check DuckLake documentation: https://ducklake.select/
- Oracle Cloud documentation: https://docs.oracle.com/iaas/
