INSTALL ducklake;
INSTALL postgres;

CREATE OR REPLACE SECRET postgres_secret (
    TYPE postgres,
    HOST getenv('POSTGRES_HOST'),
    PORT 5432,
    DATABASE ducklake_catalog,
    USER 'ducklake',
    PASSWORD getenv('POSTGRES_DB_PASSWORD')
);

-- DuckLake with local storage (default) or S3 (if configured)
-- Set LOCAL_DATA_PATH in .env for local storage: /mnt/data/ducklake
-- Set S3_DATA_PATH in .env for S3 storage: s3://bucket-name/
CREATE SECRET ducklake_secret (
    TYPE ducklake,
    METADATA_PATH '',
    DATA_PATH COALESCE(getenv('S3_DATA_PATH'), getenv('LOCAL_DATA_PATH'), '/mnt/data/ducklake'),
    METADATA_PARAMETERS MAP {'TYPE': 'postgres', 'SECRET': 'postgres_secret'}
);

ATTACH 'ducklake:ducklake_secret' AS ducklake;
USE ducklake;
SELECT 'DuckLake is ready - using storage at: ' || COALESCE(getenv('S3_DATA_PATH'), getenv('LOCAL_DATA_PATH'), '/mnt/data/ducklake') as status;
