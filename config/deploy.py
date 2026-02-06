from pyinfra.operations import apt, iptables, server
from os import getenv
from tasks.postgres import setup_postgres
from tasks.secure import setup_firewall, persist_firewall_config

def deploy():
    setup_postgres(db_password=getenv("POSTGRES_DB_PASSWORD"))
    iptables.rule(
            name="Allow PostgreSQL traffic",
            chain="INPUT",
            jump="ACCEPT",
            protocol="tcp",
            destination_port=5432,
        )
    setup_firewall()
    persist_firewall_config()
    server.shell(
        name="Install fail2ban for SSH protection",
        commands=["sudo dnf install -y fail2ban || sudo apt-get install -y fail2ban"],
    )

deploy()
