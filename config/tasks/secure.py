from pyinfra.operations import server, iptables, apt


def setup_firewall() -> None:
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

    # Set default policies (must run after allowing SSH, else SSH will be blocked)
    iptables.chain(chain="INPUT", policy="DROP")
    iptables.chain(chain="FORWARD", policy="DROP")
    iptables.chain(chain="OUTPUT", policy="ACCEPT")


def persist_firewall_config() -> None:
    apt.update(cache_time=3600)

    apt.packages(
        packages=["iptables-persistent"],
        present=True,
    )

    server.shell(
        name="Save iptables rules",
        commands=["netfilter-persistent save"],
    )
