from pyinfra.operations import server, apt, postgres, files

def setup_postgres(db_password: str = "changeme"):
    # For Oracle Linux, we need to use dnf instead of apt
    # Check if we're on Oracle Linux or Ubuntu
    server.shell(
        name="Install PostgreSQL repository for Oracle Linux",
        commands=[
            "sudo dnf install -y oracle-epel-release-el8 || true",
            "sudo dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-aarch64/pgdg-redhat-repo-latest.noarch.rpm || true",
            "sudo dnf -qy module disable postgresql || true",
        ],
    )

    server.shell(
        name="Install PostgreSQL on Oracle Linux",
        commands=[
            "sudo dnf install -y postgresql16-server postgresql16 || sudo apt-get update && sudo apt-get install -y postgresql",
        ],
    )

    server.shell(
        name="Initialize PostgreSQL database",
        commands=[
            "sudo /usr/pgsql-16/bin/postgresql-16-setup initdb || true",
            "sudo systemctl enable postgresql-16 || sudo systemctl enable postgresql",
            "sudo systemctl start postgresql-16 || sudo systemctl start postgresql",
        ],
    )

    # Configure locale (needed for PostgreSQL)
    server.locale(
        name="Ensure en_US.UTF-8 locale is present",
        locale="en_US.UTF-8",
    )

    postgres.role(name="Create a role", role="ducklake", password=db_password, _su_user="postgres")

    postgres.database(
        database="ducklake_catalog",
        owner="ducklake",
        template="template0",
        encoding="UTF8",
        lc_collate="en_US.UTF-8",
        lc_ctype="en_US.UTF-8",
        _su_user="postgres",
    )

    # Determine PostgreSQL config path
    server.shell(
        name="Configure PostgreSQL to listen on all addresses",
        commands=[
            "sudo sed -i \"s/#listen_addresses = 'localhost'/listen_addresses = '*'/g\" /var/lib/pgsql/16/data/postgresql.conf || sudo sed -i \"s/#listen_addresses = 'localhost'/listen_addresses = '*'/g\" /etc/postgresql/16/main/postgresql.conf",
            "echo 'host    ducklake_catalog           ducklake         0.0.0.0/0          md5' | sudo tee -a /var/lib/pgsql/16/data/pg_hba.conf || echo 'host    ducklake_catalog           ducklake         0.0.0.0/0          md5' | sudo tee -a /etc/postgresql/16/main/pg_hba.conf",
            "sudo systemctl restart postgresql-16 || sudo systemctl restart postgresql",
        ],
    )
