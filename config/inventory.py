from pathlib import Path
import os

def get_ip_from_env():
    """Get instance IP from environment variable"""
    ip = os.getenv('INSTANCE_IP')
    if not ip:
        raise ValueError("INSTANCE_IP environment variable is not set")
    return ip

postgres = [get_ip_from_env()]
