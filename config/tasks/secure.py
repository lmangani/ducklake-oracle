from pyinfra.operations import server, iptables, apt


def setup_firewall() -> None:
    # Oracle Linux uses firewalld by default, but we can use iptables for compatibility
    # Or use firewalld commands
    server.shell(
        name="Configure firewalld for Oracle Linux",
        commands=[
            "sudo systemctl enable firewalld || true",
            "sudo systemctl start firewalld || true",
            "sudo firewall-cmd --permanent --add-service=ssh || true",
            "sudo firewall-cmd --permanent --add-port=5432/tcp || true",
            "sudo firewall-cmd --reload || true",
        ],
    )
    
    # Fallback to iptables if firewalld is not available
    iptables.rule(
        name="Allow loopback input",
        chain="INPUT",
        jump="ACCEPT",
        in_interface="lo",
    )

    iptables.rule(
        name="Allow loopback output",
        chain="OUTPUT",
        jump="ACCEPT",
        out_interface="lo",
    )

    iptables.rule(
        name="Allow established and related connections",
        chain="INPUT",
        jump="ACCEPT",
        extras="-m conntrack --ctstate ESTABLISHED,RELATED",
    )

    iptables.rule(
        name="Allow SSH on port 22",
        chain="INPUT",
        jump="ACCEPT",
        protocol="tcp",
        destination_port=22,
    )


def persist_firewall_config() -> None:
    server.shell(
        name="Install and configure firewall persistence",
        commands=[
            "sudo dnf install -y iptables-services || sudo apt-get update && sudo apt-get install -y iptables-persistent",
            "sudo systemctl enable iptables || true",
            "sudo service iptables save || sudo netfilter-persistent save || true",
        ],
    )
