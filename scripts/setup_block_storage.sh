#!/bin/bash
# Setup block storage on Oracle Cloud instance
# This script formats and mounts a block volume if one is attached

set -e

echo "=== Block Storage Setup ==="

# Check if block device exists (common paths for OCI block volumes)
BLOCK_DEVICE=""
for dev in /dev/sdb /dev/oracleoci/oraclevdb /dev/xvdb; do
    if [ -b "$dev" ]; then
        BLOCK_DEVICE="$dev"
        echo "Found block device: $BLOCK_DEVICE"
        break
    fi
done

if [ -z "$BLOCK_DEVICE" ]; then
    echo "No block volume found. Using boot volume only."
    echo "To attach a block volume:"
    echo "  1. Go to OCI Console → Compute → Instances"
    echo "  2. Select your instance → Attached Block Volumes"
    echo "  3. Click 'Attach Block Volume' and follow the prompts"
    exit 0
fi

# Check if already mounted
if mount | grep -q "$BLOCK_DEVICE"; then
    echo "Block device $BLOCK_DEVICE is already mounted"
    mount | grep "$BLOCK_DEVICE"
    exit 0
fi

# Check if already has a filesystem
if sudo file -s "$BLOCK_DEVICE" | grep -q filesystem; then
    echo "Block device already has a filesystem"
else
    echo "Formatting block device $BLOCK_DEVICE as ext4..."
    sudo mkfs.ext4 -F "$BLOCK_DEVICE"
fi

# Create mount point
MOUNT_POINT="/mnt/data"
echo "Creating mount point: $MOUNT_POINT"
sudo mkdir -p "$MOUNT_POINT"

# Mount the volume
echo "Mounting $BLOCK_DEVICE to $MOUNT_POINT"
sudo mount "$BLOCK_DEVICE" "$MOUNT_POINT"

# Add to fstab for persistence
if ! grep -q "$BLOCK_DEVICE" /etc/fstab; then
    echo "Adding to /etc/fstab for automatic mounting on boot"
    echo "$BLOCK_DEVICE $MOUNT_POINT ext4 defaults,nofail 0 2" | sudo tee -a /etc/fstab
fi

# Create ducklake directory
echo "Creating DuckLake data directory"
sudo mkdir -p "$MOUNT_POINT/ducklake"
sudo chown -R $(whoami):$(whoami) "$MOUNT_POINT/ducklake"

echo ""
echo "=== Block Storage Setup Complete ==="
df -h "$MOUNT_POINT"
