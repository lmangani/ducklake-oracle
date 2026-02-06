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
-- Uses LOCAL_DATA_PATH from environment (default: /mnt/data/ducklake)
-- Or S3_DATA_PATH if you want S3 storage instead
CREATE SECRET ducklake_secret (
    TYPE ducklake,
    METADATA_PATH '',
    DATA_PATH COALESCE(getenv('S3_DATA_PATH'), getenv('LOCAL_DATA_PATH')),
    METADATA_PARAMETERS MAP {'TYPE': 'postgres', 'SECRET': 'postgres_secret'}
);

ATTACH 'ducklake:ducklake_secret' AS ducklake;
USE ducklake;
SELECT 'DuckLake is ready - using storage at: ' || COALESCE(getenv('S3_DATA_PATH'), getenv('LOCAL_DATA_PATH')) as status;
