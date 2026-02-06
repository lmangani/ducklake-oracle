# Oracle Cloud Configuration Quick Reference

## Required Environment Variables

```bash
# OCI Authentication
export TF_VAR_oci_tenancy_ocid="ocid1.tenancy.oc1..aaa..."
export TF_VAR_oci_user_ocid="ocid1.user.oc1..aaa..."
export TF_VAR_oci_fingerprint="12:34:56:78:90:ab:cd:ef:..."
export TF_VAR_oci_private_key_path="~/.oci/oci_api_key.pem"
export TF_VAR_oci_region="us-ashburn-1"
export TF_VAR_oci_compartment_id="ocid1.compartment.oc1..aaa..."
export TF_VAR_oci_namespace="your-namespace"

# SSH Configuration
export TF_VAR_ssh_public_key_path="~/.ssh/id_rsa.pub"
export SSH_KEY_PATH="~/.ssh/id_rsa"

# PostgreSQL Configuration
export POSTGRES_DB_PASSWORD="your-secure-password"
export POSTGRES_HOST="<instance-ip>"  # Set after deployment

# S3 Configuration (Customer Secret Keys from OCI Console)
export S3_ACCESS_KEY="your-access-key"
export S3_SECRET_KEY="your-secret-key"
export S3_ENDPOINT="your-namespace.compat.objectstorage.us-ashburn-1.oraclecloud.com"
export S3_REGION="us-ashburn-1"
export S3_BUCKET_NAME="ducklake-bucket"
export S3_DATA_PATH="s3://$S3_BUCKET_NAME/"
export S3_USE_SSL=true
```

## Common Commands

```bash
# Initial setup
cp .env.sample .env
# Edit .env with your values
set -a && source .env && set +a

# Deploy infrastructure
make init
make terraform-apply

# Update POSTGRES_HOST in .env with the IP from terraform output
make deploy

# Connect to DuckDB
make duckdb

# Destroy everything
make destroy
```

## How to Get OCI Values

### Tenancy OCID
Console → Tenancy Details → Copy OCID

### User OCID
Console → User Settings → Copy OCID

### Compartment OCID
Console → Identity → Compartments → Select compartment → Copy OCID
(Or use tenancy OCID for root compartment)

### Namespace
Console → Object Storage → Buckets → View Namespace

### API Key Fingerprint
After adding public key to Console → User Settings → API Keys
The fingerprint is displayed in the key details

### Customer Secret Keys (for S3)
Console → User Settings → Customer Secret Keys → Generate Secret Key
Save both Access Key and Secret Key (shown only once)

## Regions

Common Oracle Cloud regions:
- `us-ashburn-1` (US East, Ashburn, VA)
- `us-phoenix-1` (US West, Phoenix, AZ)
- `uk-london-1` (UK South, London)
- `eu-frankfurt-1` (Germany Central, Frankfurt)
- `ap-tokyo-1` (Japan East, Tokyo)
- `ap-singapore-1` (Singapore)

## ARM64 Instance Shapes

- `VM.Standard.A1.Flex` - Ampere A1 (ARM64)
  - Flexible OCPUs: 1-4 (Free tier)
  - Memory: 1-24 GB (Free tier)
  - Always Free: Up to 4 OCPUs and 24 GB total across all instances

## Block Volume Sizes

- Boot Volume: 50 GB (configured in terraform)
- Additional Block Volume: 50 GB (configured in terraform)
- Free Tier Total: 200 GB across all volumes

## Useful OCI CLI Commands

```bash
# List instances
oci compute instance list --compartment-id <compartment-ocid>

# List block volumes
oci bv volume list --compartment-id <compartment-ocid>

# List buckets
oci os bucket list --compartment-id <compartment-ocid> --namespace-name <namespace>

# Get instance public IP
oci compute instance list-vnics --instance-id <instance-ocid> --query 'data[0]."public-ip"'
```

## Default Credentials

- **SSH User**: `opc` (Oracle Cloud default user)
- **PostgreSQL User**: `ducklake`
- **PostgreSQL Database**: `ducklake_catalog`
- **PostgreSQL Port**: `5432`

## Free Tier Limits

- **Compute**: 4 ARM OCPUs, 24 GB RAM
- **Block Storage**: 200 GB total
- **Object Storage**: First 10 GB free
- **Load Balancer**: 1 (10 Mbps)
- **Outbound Data Transfer**: 10 TB/month
- **Archive Storage**: 20 GB/month
- **Notifications**: 1,000,000/month
- **Monitoring**: 500 million ingestion points/month
