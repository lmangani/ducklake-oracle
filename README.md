# DuckLake on Oracle Cloud

Deploy [DuckLake](https://ducklake.select/) on your existing Oracle Cloud ARM64 instance.

**What you get:** PostgreSQL for metadata, local block storage for data, DuckDB as the query engine. Optional Oracle Cloud Object Storage support.

## Quick Start

This setup assumes you already have an Oracle Cloud instance provisioned. The scripts will configure DuckDB, PostgreSQL, and storage on your existing instance.

## Prerequisites

- An existing Oracle Cloud ARM64 instance (VM.Standard.A1.Flex recommended)
- SSH access to your instance
- [uv](https://docs.astral.sh/uv/) (Python package manager)
- [DuckDB](https://duckdb.org/) v1.3.0+ installed locally

## Instance Requirements

Your Oracle Cloud instance should have:
- **OS:** Oracle Linux 8 or Ubuntu 20.04+ (ARM64)
- **RAM:** At least 4 GB (12 GB recommended for better performance)
- **Storage:** Boot volume + optional block volume
- **Network:** Public IP with ports 22 (SSH) and 5432 (PostgreSQL) open

### Recommended Instance Configuration

Use Oracle Cloud Free Tier:
- **Shape:** VM.Standard.A1.Flex
- **OCPUs:** 2-4 (Free tier allows up to 4 total)
- **Memory:** 12-24 GB (Free tier allows up to 24 GB total)
- **Boot Volume:** 50 GB
- **Block Volume:** 50-100 GB (optional, Free tier includes 200 GB total)

## Setup

### 1. Create Your Oracle Cloud Instance

1. Log into [Oracle Cloud Console](https://cloud.oracle.com/)
2. Navigate to: Compute → Instances → Create Instance
3. Configure:
   - **Name:** ducklake-server
   - **Image:** Oracle Linux 8 (ARM64) or Ubuntu 22.04 (ARM64)
   - **Shape:** VM.Standard.A1.Flex (2-4 OCPUs, 12-24 GB RAM)
   - **VCN:** Create new or use existing
   - **Public IP:** Assign a public IPv4 address
   - **SSH Keys:** Add your public SSH key
4. Click "Create"
5. Note the public IP address once instance is running

### 2. Configure Security List

Ensure your VCN Security List allows:
- **SSH (22):** From your IP or 0.0.0.0/0
- **PostgreSQL (5432):** From your IP or 0.0.0.0/0

### 3. Optional: Attach Block Volume

For additional storage:
1. Navigate to: Block Storage → Block Volumes → Create Block Volume
2. Configure:
   - **Name:** ducklake-data
   - **Size:** 50-100 GB
   - **Availability Domain:** Same as your instance
3. Attach to your instance:
   - Go to your instance → Attached Block Volumes → Attach Block Volume
   - Select the volume you created

### 4. Configure Environment

```bash
cp .env.sample .env
```

Edit `.env` and set:
```bash
INSTANCE_IP="<your-instance-public-ip>"
SSH_KEY_PATH="~/.ssh/id_rsa"
POSTGRES_DB_PASSWORD="your-secure-password"
```

Then source it:
```bash
set -a && source .env && set +a
```

### 5. Deploy

```bash
make deploy
```

This will:
- Install and configure PostgreSQL 16
- Set up firewall rules
- Install fail2ban for security
- Configure the database for DuckLake

If you attached a block volume, set it up:
```bash
make setup-storage
```

### 6. Update Environment

After deployment, set `POSTGRES_HOST` in `.env`:
```bash
POSTGRES_HOST="<your-instance-ip>"
```

Reload environment:
```bash
set -a && source .env && set +a
```

### 7. Connect with DuckDB

```bash
make duckdb
```

You're now connected to your DuckLake. Try it:

```sql
-- Create a table with local storage
CREATE TABLE test_data AS
    SELECT * FROM 'https://duckdb.org/data/flights.csv' LIMIT 1000;

SELECT * FROM test_data LIMIT 10;
```

## Storage Options

### Local Block Storage (Default)

Data is stored on the instance's block volume at `/mnt/data/ducklake`.

**Pros:**
- Simple setup
- No additional costs
- Fast access
- Free tier includes 200 GB total storage

**Cons:**
- Data tied to instance
- Need backups for disaster recovery

### Oracle Cloud Object Storage (Optional)

To use S3-compatible Object Storage, uncomment and configure in `.env`:

```bash
# Create Customer Secret Keys in OCI Console → User Settings
S3_ACCESS_KEY="your-access-key"
S3_SECRET_KEY="your-secret-key"
S3_ENDPOINT="namespace.compat.objectstorage.us-ashburn-1.oraclecloud.com"
S3_REGION="us-ashburn-1"
S3_BUCKET_NAME="ducklake-data"
S3_DATA_PATH="s3://$S3_BUCKET_NAME/"
S3_USE_SSL=true
```

Then create the bucket manually in OCI Console → Object Storage → Create Bucket.

**Pros:**
- Decoupled from compute
- Durable storage (11 9's durability)
- Easy to scale
- First 10 GB free

**Cons:**
- Additional cost ($0.026/GB/month after 10 GB)
- Requires S3 API setup
- Network latency

## Security

### Firewall Configuration

The deployment automatically configures:
- **firewalld** (Oracle Linux) allowing SSH (22) and PostgreSQL (5432)
- **fail2ban** for SSH brute-force protection

### PostgreSQL Access

By default, PostgreSQL accepts connections from any IP (`0.0.0.0/0`). For production:

1. SSH into your instance
2. Edit `/var/lib/pgsql/16/data/pg_hba.conf` (or `/etc/postgresql/16/main/pg_hba.conf` for Ubuntu)
3. Replace `0.0.0.0/0` with your specific IP/CIDR
4. Restart PostgreSQL: `sudo systemctl restart postgresql-16`

### OCI Security List

Consider restricting Security List rules to your IP address instead of `0.0.0.0/0`.

## Cost

**Oracle Cloud Free Tier (Always Free):**
- **Compute:** FREE (VM.Standard.A1.Flex: up to 4 OCPUs, 24 GB RAM)
- **Boot Volume:** FREE (50 GB)
- **Block Volume:** FREE (up to 200 GB total)
- **Object Storage:** FREE (first 10 GB)
- **Outbound Transfer:** FREE (10 TB/month)

**Total:** $0/month for typical small-medium workloads within free tier limits

**Beyond Free Tier:**
- Additional Object Storage: ~$0.026/GB/month
- Additional Compute: Pay-as-you-go pricing

## Structure

```
config/      # PyInfra deployment scripts
scripts/     # Helper scripts (block storage setup)
init.sql     # DuckDB initialization script
Makefile     # Deployment automation
```

## Common Tasks

### Connect to Instance

```bash
ssh -i ~/.ssh/id_rsa opc@<instance-ip>
```

### Check PostgreSQL Status

```bash
sudo systemctl status postgresql-16
```

### View PostgreSQL Logs

```bash
sudo journalctl -u postgresql-16 -n 50 -f
```

### Check Storage Usage

```bash
df -h /mnt/data
```

### Backup PostgreSQL

```bash
ssh -i ~/.ssh/id_rsa opc@<instance-ip>
sudo -u postgres pg_dump ducklake_catalog > backup.sql
```

### Restore PostgreSQL

```bash
scp backup.sql opc@<instance-ip>:/tmp/
ssh -i ~/.ssh/id_rsa opc@<instance-ip>
sudo -u postgres psql ducklake_catalog < /tmp/backup.sql
```

## Troubleshooting

### SSH Connection Issues

```bash
# Verify instance is running in OCI Console
# Check Security List allows SSH from your IP
# Test connection
ssh -v -i ~/.ssh/id_rsa opc@<instance-ip>
```

### PostgreSQL Connection Refused

```bash
# Check PostgreSQL is running
ssh -i ~/.ssh/id_rsa opc@<instance-ip>
sudo systemctl status postgresql-16

# Check it's listening
sudo netstat -tlnp | grep 5432

# Verify firewall
sudo firewall-cmd --list-all
```

### Deployment Fails

```bash
# Check Python/uv installation
uv --version

# Run with verbose output
cd config && pyinfra inventory.py deploy.py --key "$SSH_KEY_PATH" --user opc --sudo -vv
```

### Block Volume Not Detected

```bash
# SSH into instance and check for block devices
ssh -i ~/.ssh/id_rsa opc@<instance-ip>
lsblk

# If you see sdb or similar, run setup script
# From your local machine:
make setup-storage
```

## Performance Tips

1. **Use ARM-optimized PostgreSQL** (automatically installed)
2. **Allocate more OCPUs** if queries are slow (up to 4 in free tier)
3. **Use Parquet files** for better compression and query performance
4. **Partition large tables** by date or other columns
5. **Monitor with:** `top`, `htop`, `iostat -x 2`

## Resources

- [DuckLake Documentation](https://ducklake.select/)
- [DuckDB PostgreSQL Extension](https://duckdb.org/docs/extensions/postgres.html)
- [Oracle Cloud Free Tier](https://www.oracle.com/cloud/free/)
- [Oracle Cloud Documentation](https://docs.oracle.com/iaas/)

## Examples

See [EXAMPLES.md](EXAMPLES.md) for comprehensive DuckDB query examples.

## Support

For issues:
1. Check troubleshooting section above
2. Review deployment logs
3. Check Oracle Cloud instance console logs
4. Open an issue in the repository
