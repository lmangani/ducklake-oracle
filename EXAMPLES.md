# DuckLake Examples

Collection of practical examples for using DuckLake.

## Table of Contents

- [Basic Operations](#basic-operations)
- [Data Import](#data-import)
- [Data Export](#data-export)
- [Querying Data](#querying-data)
- [Working with S3](#working-with-s3)
- [Analytics Queries](#analytics-queries)

## Basic Operations

### List All Tables

```sql
SELECT * FROM list_tables();
```

### Check Storage Configuration

```sql
SELECT * FROM storage_info();
```

### Get Metadata Information

```sql
-- View metadata tables
SHOW TABLES FROM metadata;

-- Count tables
SELECT COUNT(*) as table_count FROM metadata.tables;

-- View catalogs
SELECT * FROM metadata.catalogs;
```

## Data Import

### From CSV File

```sql
-- Simple import
CREATE TABLE users AS 
SELECT * FROM read_csv_auto('users.csv');

-- With options
CREATE TABLE products AS 
SELECT * FROM read_csv_auto('products.csv', 
    header=true, 
    delimiter=',',
    auto_detect=true
);

-- From specific columns
CREATE TABLE orders AS 
SELECT order_id, customer_id, total 
FROM read_csv_auto('orders.csv');
```

### From Parquet Files

```sql
-- Single file
CREATE TABLE events AS 
SELECT * FROM read_parquet('events.parquet');

-- Multiple files (glob pattern)
CREATE TABLE logs AS 
SELECT * FROM read_parquet('logs/*.parquet');

-- With schema
CREATE TABLE sales AS 
SELECT 
    CAST(sale_date AS DATE) as sale_date,
    product_id,
    quantity,
    price
FROM read_parquet('sales.parquet');
```

### From JSON

```sql
-- JSON Lines format
CREATE TABLE api_logs AS 
SELECT * FROM read_json_auto('logs.jsonl');

-- Regular JSON array
CREATE TABLE config AS 
SELECT * FROM read_json_auto('config.json');
```

### From URL

```sql
-- Public CSV
CREATE TABLE flights AS 
SELECT * FROM 'https://duckdb.org/data/flights.csv' LIMIT 10000;

-- Public Parquet
CREATE TABLE taxi AS 
SELECT * FROM read_parquet('https://example.com/data/taxi.parquet');
```

### From Database

```sql
-- Attach SQLite database
ATTACH 'other.db' AS other_db (TYPE sqlite);

-- Import table
CREATE TABLE imported AS 
SELECT * FROM other_db.source_table;
```

## Data Export

### To Parquet

```sql
-- Export to local storage
COPY users TO '/var/lib/ducklake/data/users.parquet' (FORMAT PARQUET);

-- With compression
COPY large_table TO '/var/lib/ducklake/data/large.parquet' 
    (FORMAT PARQUET, COMPRESSION 'ZSTD');

-- Partitioned export
COPY events TO '/var/lib/ducklake/data/events' 
    (FORMAT PARQUET, PARTITION_BY (year, month));
```

### To CSV

```sql
-- Basic export
COPY users TO '/var/lib/ducklake/data/users.csv' 
    (HEADER, DELIMITER ',');

-- With custom delimiter
COPY data TO '/var/lib/ducklake/data/data.tsv' 
    (HEADER, DELIMITER '\t');
```

### To JSON

```sql
-- JSON Lines
COPY users TO '/var/lib/ducklake/data/users.jsonl';

-- Array format
COPY users TO '/var/lib/ducklake/data/users.json' 
    (ARRAY true);
```

## Querying Data

### Basic Queries

```sql
-- Select all
SELECT * FROM users LIMIT 10;

-- Filter
SELECT * FROM users WHERE age > 25;

-- Aggregate
SELECT 
    country,
    COUNT(*) as user_count,
    AVG(age) as avg_age
FROM users
GROUP BY country
ORDER BY user_count DESC;
```

### Joins

```sql
-- Inner join
SELECT 
    u.name,
    o.order_id,
    o.total
FROM users u
JOIN orders o ON u.id = o.user_id;

-- Left join with aggregation
SELECT 
    u.name,
    COUNT(o.order_id) as order_count,
    SUM(o.total) as total_spent
FROM users u
LEFT JOIN orders o ON u.id = o.user_id
GROUP BY u.name;
```

### Window Functions

```sql
-- Running total
SELECT 
    order_date,
    total,
    SUM(total) OVER (ORDER BY order_date) as running_total
FROM orders
ORDER BY order_date;

-- Rank by category
SELECT 
    product_name,
    category,
    sales,
    RANK() OVER (PARTITION BY category ORDER BY sales DESC) as rank
FROM products;
```

### Time Series

```sql
-- Group by date
SELECT 
    DATE_TRUNC('day', timestamp) as date,
    COUNT(*) as event_count
FROM events
GROUP BY date
ORDER BY date;

-- Moving average
SELECT 
    date,
    value,
    AVG(value) OVER (
        ORDER BY date 
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) as moving_avg_7d
FROM metrics;
```

## Working with S3

### Configure S3 (in session)

```sql
-- Set S3 credentials
SET s3_endpoint='s3.amazonaws.com';
SET s3_region='us-east-1';
SET s3_access_key_id='your-key';
SET s3_secret_access_key='your-secret';
SET s3_use_ssl=true;
```

### Read from S3

```sql
-- Single file
CREATE TABLE s3_data AS 
SELECT * FROM read_parquet('s3://my-bucket/data.parquet');

-- Multiple files
CREATE TABLE s3_logs AS 
SELECT * FROM read_parquet('s3://my-bucket/logs/*.parquet');

-- With path pattern
CREATE TABLE partitioned AS 
SELECT * FROM read_parquet('s3://my-bucket/year=*/month=*/*.parquet');
```

### Write to S3

```sql
-- Export to S3
COPY users TO 's3://my-bucket/users.parquet' (FORMAT PARQUET);

-- Partitioned write
COPY events TO 's3://my-bucket/events' 
    (FORMAT PARQUET, PARTITION_BY (year, month));
```

## Analytics Queries

### Top N Analysis

```sql
-- Top 10 customers by revenue
SELECT 
    customer_id,
    SUM(total) as revenue
FROM orders
GROUP BY customer_id
ORDER BY revenue DESC
LIMIT 10;
```

### Cohort Analysis

```sql
-- Monthly cohorts
WITH first_purchase AS (
    SELECT 
        user_id,
        MIN(DATE_TRUNC('month', purchase_date)) as cohort_month
    FROM orders
    GROUP BY user_id
)
SELECT 
    f.cohort_month,
    DATE_TRUNC('month', o.purchase_date) as purchase_month,
    COUNT(DISTINCT o.user_id) as users
FROM orders o
JOIN first_purchase f ON o.user_id = f.user_id
GROUP BY f.cohort_month, purchase_month
ORDER BY f.cohort_month, purchase_month;
```

### Statistical Analysis

```sql
-- Descriptive statistics
SELECT 
    COUNT(*) as count,
    AVG(value) as mean,
    STDDEV(value) as std_dev,
    MIN(value) as min,
    APPROX_QUANTILE(value, 0.25) as q25,
    APPROX_QUANTILE(value, 0.5) as median,
    APPROX_QUANTILE(value, 0.75) as q75,
    MAX(value) as max
FROM metrics;
```

### Data Quality Checks

```sql
-- Find duplicates
SELECT 
    email,
    COUNT(*) as count
FROM users
GROUP BY email
HAVING COUNT(*) > 1;

-- Null analysis
SELECT 
    COUNT(*) as total_rows,
    COUNT(*) - COUNT(email) as null_emails,
    COUNT(*) - COUNT(phone) as null_phones,
    (COUNT(*) - COUNT(email))::FLOAT / COUNT(*) * 100 as null_email_pct
FROM users;

-- Value distribution
SELECT 
    status,
    COUNT(*) as count,
    COUNT(*)::FLOAT / SUM(COUNT(*)) OVER () * 100 as percentage
FROM orders
GROUP BY status
ORDER BY count DESC;
```

### Text Search

```sql
-- Pattern matching
SELECT * FROM products 
WHERE name LIKE '%laptop%';

-- Case-insensitive search
SELECT * FROM products 
WHERE LOWER(name) LIKE '%laptop%';

-- Multiple patterns
SELECT * FROM products 
WHERE name ~ '(laptop|desktop|tablet)';
```

## Performance Tips

### Use Parquet Format

Parquet is columnar and compressed, perfect for analytics:

```sql
-- Convert CSV to Parquet
COPY (SELECT * FROM read_csv_auto('large_file.csv'))
TO '/var/lib/ducklake/data/large_file.parquet' (FORMAT PARQUET);
```

### Filter Early

Push filters down when possible:

```sql
-- Good: Filter in subquery
SELECT AVG(price) FROM (
    SELECT price FROM products WHERE category = 'Electronics'
) sub;

-- Better: Filter directly
SELECT AVG(price) FROM products WHERE category = 'Electronics';
```

### Use Appropriate Data Types

```sql
-- Efficient storage
CREATE TABLE optimized AS 
SELECT 
    CAST(id AS INTEGER) as id,
    CAST(timestamp AS TIMESTAMP) as timestamp,
    CAST(value AS DECIMAL(10,2)) as value
FROM source;
```

## More Resources

- [DuckDB Documentation](https://duckdb.org/docs/)
- [DuckDB SQL Introduction](https://duckdb.org/docs/sql/introduction)
- [DuckLake Documentation](https://ducklake.select/)
