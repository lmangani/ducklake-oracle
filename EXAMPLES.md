# Example DuckDB Queries for DuckLake on Oracle Cloud

## Basic Setup Verification

```sql
-- Check installed extensions
SELECT * FROM duckdb_extensions() WHERE installed = true;

-- Verify secrets are configured
SELECT name, type FROM duckdb_secrets();

-- Show available databases
SHOW DATABASES;

-- Show tables in DuckLake
USE ducklake;
SHOW TABLES;
```

## Loading Data Examples

### 1. Load CSV from URL

```sql
-- Create table from CSV
CREATE TABLE flights AS
    SELECT * FROM 'https://duckdb.org/data/flights.csv';

-- Query the data
SELECT origin, dest, COUNT(*) as flight_count
FROM flights
GROUP BY origin, dest
ORDER BY flight_count DESC
LIMIT 10;
```

### 2. Load Parquet from S3

```sql
-- Load from Oracle Cloud Object Storage
CREATE TABLE my_parquet_data AS
    SELECT * FROM read_parquet('s3://ducklake-bucket/data/*.parquet');

-- Query specific columns
SELECT column1, column2, COUNT(*)
FROM my_parquet_data
GROUP BY column1, column2;
```

### 3. Load JSON data

```sql
-- Create table from JSON
CREATE TABLE api_data AS
    SELECT * FROM read_json_auto('https://api.example.com/data.json');

-- Or from S3
CREATE TABLE s3_json AS
    SELECT * FROM read_json_auto('s3://ducklake-bucket/logs/*.json');
```

## Data Transformation Examples

### 4. ETL Pipeline

```sql
-- Create staging table
CREATE TABLE staging_sales AS
    SELECT * FROM read_csv_auto('s3://ducklake-bucket/raw/sales_*.csv');

-- Transform and load into final table
CREATE TABLE clean_sales AS
SELECT
    CAST(id AS INTEGER) as sale_id,
    UPPER(customer_name) as customer_name,
    CAST(amount AS DECIMAL(10,2)) as amount,
    STRPTIME(sale_date, '%Y-%m-%d')::DATE as sale_date,
    LOWER(region) as region
FROM staging_sales
WHERE amount > 0;

-- Add aggregations
CREATE TABLE sales_summary AS
SELECT
    DATE_TRUNC('month', sale_date) as month,
    region,
    COUNT(*) as total_sales,
    SUM(amount) as total_revenue,
    AVG(amount) as avg_sale
FROM clean_sales
GROUP BY month, region;
```

## Advanced Queries

### 5. Window Functions

```sql
-- Rank products by sales within each category
CREATE TABLE product_rankings AS
SELECT
    category,
    product_name,
    total_sales,
    RANK() OVER (PARTITION BY category ORDER BY total_sales DESC) as rank
FROM product_sales;
```

### 6. Time Series Analysis

```sql
-- Calculate moving averages
CREATE TABLE sales_trends AS
SELECT
    sale_date,
    daily_sales,
    AVG(daily_sales) OVER (
        ORDER BY sale_date
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) as moving_avg_7_day
FROM daily_sales_data;
```

## Working with Multiple Data Sources

### 7. Join S3 and PostgreSQL Data

```sql
-- Attach PostgreSQL database directly
ATTACH 'host=localhost user=postgres password=secret dbname=mydb' AS pg (TYPE POSTGRES);

-- Join S3 data with PostgreSQL tables
CREATE TABLE enriched_data AS
SELECT
    s3_data.*,
    pg.reference_data.description,
    pg.reference_data.category
FROM 's3://ducklake-bucket/data.parquet' s3_data
LEFT JOIN pg.reference_data
    ON s3_data.ref_id = pg.reference_data.id;
```

## Export Data

### 8. Export to Parquet

```sql
-- Export query results to S3
COPY (
    SELECT * FROM sales WHERE sale_date >= '2024-01-01'
) TO 's3://ducklake-bucket/exports/sales_2024.parquet' (FORMAT PARQUET);
```

### 9. Export to CSV

```sql
-- Export to CSV
COPY (
    SELECT customer_id, customer_name, total_purchases
    FROM customer_summary
) TO 's3://ducklake-bucket/exports/customers.csv' (HEADER, DELIMITER ',');
```

## Partitioning for Performance

### 10. Create Partitioned Tables

```sql
-- Create partitioned table by date
CREATE TABLE partitioned_logs AS
SELECT * FROM read_parquet('s3://ducklake-bucket/logs/year=*/month=*/day=*/*.parquet',
    hive_partitioning = true
);

-- Query specific partition
SELECT * FROM partitioned_logs
WHERE year = 2024 AND month = 1;
```

## Monitoring and Maintenance

### 11. Check Table Sizes

```sql
-- View table statistics
SELECT
    table_name,
    estimated_size,
    column_count,
    row_count
FROM duckdb_tables()
WHERE schema_name = 'ducklake';
```

### 12. Query Performance

```sql
-- Enable profiling
PRAGMA enable_profiling;

-- Run your query
SELECT * FROM large_table WHERE condition = 'value';

-- View profiling results
PRAGMA show_profiling_output;
```

## Best Practices

1. **Use Parquet for large datasets**: Better compression and performance
2. **Partition by date**: Improves query performance for time-series data
3. **Use column selection**: Only SELECT columns you need
4. **Create indexes** (in PostgreSQL) for frequently queried metadata
5. **Monitor S3 costs**: Use lifecycle policies to move old data to cheaper storage

## Useful Commands

```sql
-- Show all tables with their storage location
SELECT * FROM information_schema.tables;

-- Clear cache
PRAGMA memory_limit='8GB';
PRAGMA threads=4;

-- Export schema
EXPORT DATABASE 's3://ducklake-bucket/backup' (FORMAT PARQUET);

-- Import schema
IMPORT DATABASE 's3://ducklake-bucket/backup';
```
