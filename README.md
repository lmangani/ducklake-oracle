# DuckLake on Oracle Cloud

Deploy a [DuckLake](https://ducklake.select/) data lakehouse on Oracle Cloud Free Tier for free (or under $5/month with additional resources).

**What you get:** PostgreSQL for metadata, Oracle Cloud Object Storage (S3-compatible) for data, DuckDB as the query engine. All managed with Terraform and PyInfra on ARM64 instances.

## Prerequisites

- [Terraform](https://www.terraform.io/) (or OpenTofu)
- [uv](https://docs.astral.sh/uv/) (Python package manager)
- [DuckDB](https://duckdb.org/) v1.3.0+
- An [Oracle Cloud](https://www.oracle.com/cloud/free/) account with:
  - A tenancy OCID, user OCID, and API key fingerprint
  - An OCI API key pair (~/.oci/oci_api_key.pem)
  - A compartment OCID
  - Object Storage namespace
  - Customer Secret Keys for S3-compatible API access

## Oracle Cloud Free Tier

Oracle Cloud offers a generous Always Free tier:
- **2 AMD-based Compute VMs** with 1/8 OCPU and 1 GB RAM each, OR
- **4 ARM-based Ampere A1 cores** and 24 GB of memory usable as:
  - 1 VM with 4 OCPUs and 24 GB RAM
  - 2 VMs with 2 OCPUs and 12 GB RAM each (default configuration)
  - Up to 4 VMs with custom OCPU/RAM allocation
- **Block Volume:** 200 GB total (2 volumes of 100 GB each or custom split)
- **Object Storage:** 10 GB (first 10 GB free, then $0.0255/GB/month)
- **Outbound Data Transfer:** 10 TB/month

This configuration uses:
- **1 ARM64 VM (VM.Standard.A1.Flex):** 2 OCPUs, 12 GB RAM, 50 GB boot volume
- **1 Block Volume:** 50 GB for data storage
- **Object Storage:** S3-compatible bucket for DuckLake data

## Structure

```
terraform/   # Terraform infrastructure (ARM64 compute instance + Object Storage bucket)
config/      # PyInfra server provisioning (PostgreSQL, firewall)
init.sql     # DuckDB initialization script
Makefile     # Deployment automation
```
Makefile     # Deployment automation
```

## Setup

### 1. Configure Oracle Cloud Infrastructure

#### Create OCI API Keys

```bash
mkdir -p ~/.oci
openssl genrsa -out ~/.oci/oci_api_key.pem 2048
chmod 600 ~/.oci/oci_api_key.pem
openssl rsa -pubout -in ~/.oci/oci_api_key.pem -out ~/.oci/oci_api_key_public.pem
```

Add the public key to your OCI user account:
1. Navigate to: Console → User Settings → API Keys → Add API Key
2. Paste the contents of `~/.oci/oci_api_key_public.pem`
3. Note the configuration file preview shown - you'll need these values

#### Get Required OCIDs

- **Tenancy OCID:** Console → Tenancy Details
- **User OCID:** Console → User Settings
- **Compartment OCID:** Console → Identity → Compartments (or use tenancy OCID for root)
- **Namespace:** Console → Object Storage → Buckets → View Namespace

#### Create Customer Secret Keys (for S3 compatibility)

1. Navigate to: Console → User Settings → Customer Secret Keys
2. Click "Generate Secret Key"
3. Save the Access Key and Secret Key (shown only once)

### 2. Configure environment

```bash
cp .env.sample .env
```

Fill in your Oracle Cloud credentials and configuration. Then source it:

```bash
set -a && source .env && set +a
```

### 3. Generate SSH keys (if needed)

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_rsa
```

Update `TF_VAR_ssh_public_key_path` and `SSH_KEY_PATH` in `.env` if using a different path.

### 4. Deploy

```bash
make init    # initialize Terraform
make all     # provision infrastructure + configure server
```

This creates an Oracle Cloud ARM64 instance with PostgreSQL and an Object Storage bucket. After `make all` completes, set `POSTGRES_HOST` in your `.env` to the server IP printed in the Terraform output.

**Note:** The initial provisioning may take 5-10 minutes as Oracle Linux installs and configures PostgreSQL on ARM64.

### 5. Connect with DuckDB

```bash
set -a && source .env && set +a
make duckdb # this runs duckdb -init init.sql, loading all relevant information
```

You're now connected to your DuckLake. Try it:

```sql
CREATE TABLE flights AS
    SELECT * FROM 'https://duckdb.org/data/flights.csv';

SELECT * FROM flights LIMIT 10;
```

## Security

This setup configures PostgreSQL to accept connections from all IP addresses (`0.0.0.0/0`). This is intentionally simple for getting started. For production use, restrict access in `config/tasks/postgres.py` by changing the pg_hba.conf configuration to your specific IP.

The Oracle Cloud Security List and firewalld only allow SSH (port 22) and PostgreSQL (port 5432). fail2ban is installed for SSH brute-force protection.

## Cost

**Free Tier (Always Free):**
- **ARM64 VM (VM.Standard.A1.Flex):** FREE (2 OCPUs, 12 GB RAM)
- **Boot Volume:** FREE (50 GB)
- **Block Volume:** FREE (50 GB)
- **Object Storage:** FREE first 10 GB, then ~$0.026/GB/month
- **Network:** FREE egress up to 10 TB/month

**Total:** $0/month for small datasets (under 10 GB), or approximately $1-5/month for 50-200 GB of data.

## Oracle Cloud vs Hetzner

This is a port of the original [DuckLake on Hetzner](https://github.com/lmangani/ducklake) project, adapted for Oracle Cloud Infrastructure:

| Feature | Hetzner | Oracle Cloud Free Tier |
|---------|---------|------------------------|
| **Compute** | cx33: 4 vCPU, 8GB RAM (€5.49/mo) | VM.Standard.A1.Flex: 2-4 ARM64 OCPUs, 12-24GB RAM (FREE) |
| **Architecture** | x86_64 | ARM64 (aarch64) |
| **Storage** | 80 GB NVMe | 50 GB boot + 50 GB block volume (FREE) |
| **Object Storage** | €3.50/TB/month | First 10 GB free, $0.026/GB after |
| **Total Cost** | ~€10/month | $0-5/month |

## Resources

- [DuckLake documentation](https://ducklake.select/)
- [DuckDB PostgreSQL Catalog](https://duckdb.org/docs/extensions/postgres.html)
- [DuckDB S3 Configuration](https://duckdb.org/docs/extensions/httpfs/s3api.html)
- [Oracle Cloud Free Tier](https://www.oracle.com/cloud/free/)
- [Oracle Cloud Terraform Provider](https://registry.terraform.io/providers/oracle/oci/latest/docs)
- [Oracle Cloud Object Storage S3 Compatibility](https://docs.oracle.com/en-us/iaas/Content/Object/Tasks/s3compatibleapi.htm)

## Architecture Notes

### ARM64 Compatibility

Oracle Cloud Free Tier uses ARM64 (aarch64) architecture. This project is configured to:
- Use Oracle Linux 8 ARM64 images
- Install PostgreSQL 16 compiled for ARM64
- Configure all services to work on ARM architecture

### Block Storage

The configuration includes a 50 GB block volume attached to the instance. To use it:

```bash
# SSH into the instance
ssh -i ~/.ssh/id_rsa opc@<instance_ip>

# Format and mount the block volume
sudo mkfs.ext4 /dev/sdb
sudo mkdir -p /mnt/data
sudo mount /dev/sdb /mnt/data
echo '/dev/sdb /mnt/data ext4 defaults 0 0' | sudo tee -a /etc/fstab

# Optional: Move PostgreSQL data to block volume
sudo systemctl stop postgresql-16
sudo mv /var/lib/pgsql/16/data /mnt/data/pgsql-data
sudo ln -s /mnt/data/pgsql-data /var/lib/pgsql/16/data
sudo systemctl start postgresql-16
```

### Object Storage S3 Endpoint

Oracle Cloud Object Storage is S3-compatible. The endpoint format is:
```
<namespace>.compat.objectstorage.<region>.oraclecloud.com
```

Example for us-ashburn-1 region:
```
mynamespace.compat.objectstorage.us-ashburn-1.oraclecloud.com
```

## Troubleshooting

### Terraform Issues

**Error: "Service error: NotAuthorizedOrNotFound"**
- Verify your OCI credentials in `.env` are correct
- Ensure your user has the necessary permissions in the compartment
- Check that the compartment OCID is correct

**Error: "Out of capacity for shape VM.Standard.A1.Flex"**
- ARM instances can be in high demand. Try:
  - Different availability domains (modify `oci_compute.tf`)
  - Different regions (change `TF_VAR_oci_region`)
  - Try again later or use a different region

**Error: "API key authentication failed"**
- Verify fingerprint matches the key added to your OCI user
- Check that `~/.oci/oci_api_key.pem` exists and has correct permissions (600)
- Ensure the public key is uploaded to Console → User Settings → API Keys

### Deployment Issues

**SSH connection fails after terraform-apply**
- Wait 2-3 minutes for instance to fully boot
- Verify security list allows SSH (port 22) from your IP
- Check instance public IP: `cd terraform && terraform output`
- Try manually: `ssh -i ~/.ssh/id_rsa opc@<instance_ip>`

**PostgreSQL installation fails**
- Check PyInfra output for specific errors
- SSH into instance and check logs: `sudo journalctl -u postgresql-16`
- Verify Oracle Linux package repositories are accessible

**Permission denied errors during deployment**
- Ensure you're using `--sudo` flag in Makefile deploy command
- Default user is `opc` (not `root`) for Oracle Linux images

### DuckDB Connection Issues

**"Connection refused" to PostgreSQL**
- Verify `POSTGRES_HOST` in `.env` is set to correct IP
- Check PostgreSQL is running: `sudo systemctl status postgresql-16`
- Verify firewall allows port 5432: `sudo firewall-cmd --list-ports`
- Test connection: `psql -h <ip> -U ducklake -d ducklake_catalog`

**S3 credentials not working**
- Verify Customer Secret Keys are correct (generated in OCI Console)
- Check S3_ENDPOINT format: `<namespace>.compat.objectstorage.<region>.oraclecloud.com`
- Ensure bucket exists: Check OCI Console → Object Storage → Buckets
- Test S3 access with AWS CLI:
  ```bash
  aws s3 ls s3://<bucket> --endpoint-url https://<endpoint>
  ```

### Resource Cleanup

To completely remove all resources:

```bash
make destroy
```

If destroy fails, manually delete from OCI Console:
1. Compute → Instances → Terminate instance
2. Compute → Block Volumes → Terminate volume
3. Networking → Virtual Cloud Networks → Delete VCN
4. Object Storage → Buckets → Delete bucket

## Examples

### Loading Data from S3

```sql
-- Load CSV from S3
CREATE TABLE my_data AS
    SELECT * FROM read_csv_auto('s3://ducklake-bucket/data.csv');

-- Load Parquet from S3
CREATE TABLE parquet_data AS
    SELECT * FROM read_parquet('s3://ducklake-bucket/*.parquet');

-- Query directly without creating table
SELECT COUNT(*) FROM 's3://ducklake-bucket/data.parquet';
```

### Working with DuckLake

```sql
-- Create a table with DuckLake (metadata in PostgreSQL, data in S3)
CREATE TABLE sales (
    id INTEGER,
    product VARCHAR,
    amount DECIMAL(10,2),
    sale_date DATE
);

-- Insert data
INSERT INTO sales VALUES
    (1, 'Widget', 29.99, '2024-01-15'),
    (2, 'Gadget', 49.99, '2024-01-16');

-- Query the data
SELECT product, SUM(amount) as total
FROM sales
GROUP BY product;

-- Data is stored in S3, metadata in PostgreSQL
SHOW TABLES;
```

### Backup and Restore

```bash
# Backup PostgreSQL metadata
ssh -i ~/.ssh/id_rsa opc@<instance_ip>
sudo -u postgres pg_dump ducklake_catalog > backup.sql

# Restore
sudo -u postgres psql ducklake_catalog < backup.sql
```

## Performance Tips

1. **Use Parquet format** for better compression and query performance
2. **Partition large tables** by date or other columns
3. **Use ARM-optimized binaries** (already configured)
4. **Scale compute** by adjusting OCPUs in `terraform/oci_compute.tf`:
   ```hcl
   shape_config {
     ocpus         = 4  # Increase for better performance
     memory_in_gbs = 24
   }
   ```
5. **Monitor costs** via OCI Console → Billing & Cost Management
