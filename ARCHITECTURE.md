# DuckLake on Oracle Cloud - Architecture

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Oracle Cloud Free Tier                        │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │   VM.Standard.A1.Flex (ARM64)                           │   │
│  │   ┌─────────────────────┐     ┌───────────────────┐    │   │
│  │   │  PostgreSQL 16      │     │  Block Storage    │    │   │
│  │   │  (Metadata Catalog) │     │  /mnt/data/       │    │   │
│  │   │  - Port 5432        │     │  - 200 GB (Free)  │    │   │
│  │   │  - ducklake_catalog │     │  - DuckLake data  │    │   │
│  │   └─────────────────────┘     └───────────────────┘    │   │
│  │            ↑                            ↑               │   │
│  │            │                            │               │   │
│  │   ┌────────┴────────────────────────────┴──────────┐   │   │
│  │   │         Security & Networking                   │   │   │
│  │   │  - firewalld (SSH: 22, PostgreSQL: 5432)       │   │   │
│  │   │  - fail2ban (SSH protection)                   │   │   │
│  │   │  - Public IP address                           │   │   │
│  │   └─────────────────────────────────────────────────┘   │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                   │
│  Optional: Object Storage (S3-compatible)                        │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Oracle Cloud Object Storage                            │   │
│  │  - S3 API endpoint                                      │   │
│  │  - First 10 GB free                                     │   │
│  │  - $0.026/GB/month after                               │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘

            ↑                           ↑
            │ SSH (22)                  │ PostgreSQL (5432)
            │                           │
┌───────────┴───────────────────────────┴──────────────────┐
│                  Local Machine                            │
│  ┌─────────────────────────────────────────────────────┐ │
│  │                DuckDB CLI                            │ │
│  │  - Query engine                                      │ │
│  │  - Connects to PostgreSQL (metadata)                │ │
│  │  - Reads from block storage or S3 (data)            │ │
│  └─────────────────────────────────────────────────────┘ │
└───────────────────────────────────────────────────────────┘
```

## Data Flow

### Query Execution

```
┌──────────┐      ┌──────────────┐      ┌─────────────┐
│  User    │─────→│   DuckDB     │─────→│ PostgreSQL  │
│  Query   │      │   (Local)    │←─────│  (Remote)   │
└──────────┘      └──────┬───────┘      └─────────────┘
                         │                     ↑
                         │ Data Access         │ Metadata
                         ↓                     │
                  ┌──────────────┐            │
                  │ Block Storage │           │
                  │  or S3 Data   │───────────┘
                  └───────────────┘
```

### Write Operation

```
1. DuckDB creates table → PostgreSQL stores metadata
2. DuckDB writes data → Block storage (/mnt/data/ducklake)
3. PostgreSQL tracks → File locations, schemas, statistics
```

## Storage Options

### Option 1: Local Block Storage (Default)

```
Oracle Cloud Instance
├── Boot Volume (50 GB)
│   ├── OS (Oracle Linux 8)
│   └── PostgreSQL installation
└── Block Volume (150 GB) → /mnt/data
    └── ducklake/
        ├── table1.parquet
        ├── table2.parquet
        └── ...
```

**Pros:** Simple, fast, included in free tier
**Cons:** Data tied to instance

### Option 2: Object Storage (Optional)

```
Oracle Cloud Instance          Oracle Object Storage
├── Boot Volume (50 GB)        ├── s3://ducklake-bucket/
│   ├── OS                    │   ├── table1.parquet
│   └── PostgreSQL            │   ├── table2.parquet
└── Block Volume (150 GB)      │   └── ...
    └── PostgreSQL data        └── (First 10 GB free)
```

**Pros:** Decoupled, durable, scalable
**Cons:** Cost, latency, setup complexity

## Deployment Architecture

```
┌────────────────────────────────────────────────────────────┐
│                    Deployment Process                       │
└────────────────────────────────────────────────────────────┘
                         │
                         ↓
┌────────────────────────────────────────────────────────────┐
│  Step 1: Manual Provisioning (Oracle Cloud Console)        │
│  - Create VM.Standard.A1.Flex instance                     │
│  - Attach block volume (optional)                          │
│  - Configure security list (ports 22, 5432)                │
└────────────────────────────────────────────────────────────┘
                         │
                         ↓
┌────────────────────────────────────────────────────────────┐
│  Step 2: Configuration (make deploy)                       │
│  ┌──────────────────────────────────────────────────────┐ │
│  │  PyInfra connects via SSH                           │ │
│  │  ├─ Install PostgreSQL 16 (ARM64)                   │ │
│  │  ├─ Create ducklake database & user                 │ │
│  │  ├─ Configure firewalld                             │ │
│  │  ├─ Install fail2ban                                │ │
│  │  └─ Start services                                  │ │
│  └──────────────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────────────┘
                         │
                         ↓
┌────────────────────────────────────────────────────────────┐
│  Step 3: Storage Setup (make setup-storage)                │
│  - Detect block volume                                     │
│  - Format as ext4                                          │
│  - Mount at /mnt/data                                      │
│  - Add to fstab                                            │
└────────────────────────────────────────────────────────────┘
                         │
                         ↓
┌────────────────────────────────────────────────────────────┐
│  Step 4: Connect (make duckdb)                             │
│  - Launch DuckDB with init.sql                             │
│  - Create secrets (PostgreSQL, Storage)                    │
│  - Attach DuckLake catalog                                 │
│  - Ready to query!                                         │
└────────────────────────────────────────────────────────────┘
```

## Network Security

```
Internet
    │
    ↓
┌─────────────────────────────────────────┐
│  Oracle Cloud Security List            │
│  ┌───────────────────────────────────┐ │
│  │ Ingress Rules:                    │ │
│  │ - SSH (22): 0.0.0.0/0            │ │
│  │ - PostgreSQL (5432): 0.0.0.0/0   │ │
│  └───────────────────────────────────┘ │
└─────────────────────────────────────────┘
    │
    ↓
┌─────────────────────────────────────────┐
│  Instance Firewall (firewalld)          │
│  ┌───────────────────────────────────┐ │
│  │ Enabled Services:                 │ │
│  │ - ssh                             │ │
│  │ - 5432/tcp                        │ │
│  │                                   │ │
│  │ Protection:                       │ │
│  │ - fail2ban (SSH brute force)     │ │
│  └───────────────────────────────────┘ │
└─────────────────────────────────────────┘
    │
    ↓
┌─────────────────────────────────────────┐
│  PostgreSQL pg_hba.conf                 │
│  - host ducklake_catalog 0.0.0.0/0 md5 │
│  (Should restrict in production)        │
└─────────────────────────────────────────┘
```

## Resource Limits (Free Tier)

```
┌────────────────────────────────────────────────────┐
│  Oracle Cloud Free Tier Limits                     │
├────────────────────────────────────────────────────┤
│  Compute (ARM64)                                   │
│  ├─ OCPUs: 4 total                                 │
│  ├─ Memory: 24 GB total                            │
│  └─ Instances: Up to 4                             │
│                                                     │
│  Block Storage                                      │
│  ├─ Total: 200 GB                                  │
│  ├─ Boot: ~50 GB per instance                      │
│  └─ Data: Remaining from 200 GB                    │
│                                                     │
│  Object Storage                                     │
│  ├─ Free: 10 GB                                    │
│  └─ Additional: $0.026/GB/month                    │
│                                                     │
│  Network                                            │
│  ├─ Outbound: 10 TB/month free                     │
│  ├─ Public IPs: Limited                            │
│  └─ Load Balancers: 1 free (10 Mbps)              │
└────────────────────────────────────────────────────┘
```

## Recommended Configuration

### Small Workload (< 50 GB data)
- **Instance:** VM.Standard.A1.Flex (2 OCPUs, 12 GB RAM)
- **Boot Volume:** 50 GB
- **Block Volume:** Not needed (use boot volume)
- **Object Storage:** Not needed
- **Cost:** $0/month

### Medium Workload (50-150 GB data)
- **Instance:** VM.Standard.A1.Flex (2 OCPUs, 12 GB RAM)
- **Boot Volume:** 50 GB
- **Block Volume:** 100-150 GB
- **Object Storage:** Optional (if need durability)
- **Cost:** $0/month (within free tier)

### Large Workload (150+ GB data)
- **Instance:** VM.Standard.A1.Flex (4 OCPUs, 24 GB RAM)
- **Boot Volume:** 50 GB
- **Block Volume:** 150 GB
- **Object Storage:** Required (for data > 200 GB)
- **Cost:** $1-10/month (depending on Object Storage usage)

## Performance Characteristics

### Query Performance (Relative to x86_64)
- **Simple queries:** 90-95% performance
- **Complex aggregations:** 85-90% performance
- **Parquet scans:** 95-100% performance
- **PostgreSQL metadata:** 100% performance

### Storage Performance
- **Block Storage:** 
  - Read: ~100-200 MB/s
  - Write: ~50-100 MB/s
  - Latency: <1ms

- **Object Storage:**
  - Read: ~50-100 MB/s
  - Write: ~25-50 MB/s
  - Latency: ~10-50ms

## Monitoring Points

```
┌──────────────────────────────────────────────────────┐
│  Key Metrics to Monitor                              │
├──────────────────────────────────────────────────────┤
│  Compute                                             │
│  ├─ CPU usage: top, htop                             │
│  ├─ Memory usage: free -h                            │
│  └─ Load average: uptime                             │
│                                                       │
│  Storage                                              │
│  ├─ Disk usage: df -h                                │
│  ├─ I/O stats: iostat -x 2                           │
│  └─ Block volume: lsblk                              │
│                                                       │
│  PostgreSQL                                           │
│  ├─ Connections: SELECT count(*) FROM pg_stat_activity│
│  ├─ Database size: \l+                                │
│  └─ Table sizes: \dt+                                 │
│                                                       │
│  Network                                              │
│  ├─ Connections: netstat -ant                         │
│  ├─ Bandwidth: iftop                                  │
│  └─ Firewall: firewall-cmd --list-all                │
└──────────────────────────────────────────────────────┘
```
