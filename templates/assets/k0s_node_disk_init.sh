#!/bin/bash

DISK="/dev/nvme1n1"
PARTITION="${DISK}p1"
MOUNT_POINT="/var/lib/k0s"

# Create mount point directory if it doesn't exist
mkdir -p $MOUNT_POINT

# Check if the disk is already partitioned
if ! lsblk $DISK | grep -q "part"; then
    echo "Partitioning $DISK..."
    echo -e "n\np\n1\n\n\nw" | fdisk $DISK
    # Refresh partition table
    partprobe $DISK
fi

# Check if the partition is already formatted
blkid $PARTITION | grep "TYPE=ext4"
FORMATTED=$?

if [ $FORMATTED -eq 1 ]; then
    echo "Formatting $PARTITION..."
    mkfs.ext4 $PARTITION
    if [ $? -eq 0 ]; then
        echo "Formatting successful."
    else
        echo "Formatting failed."
        exit 1
    fi
else
    echo "Partition is already formatted."
fi

# Mount the partition
echo "Mounting $PARTITION to $MOUNT_POINT..."
mount $PARTITION $MOUNT_POINT
if [ $? -eq 0 ]; then
    echo "Mounting successful."
else
    echo "Mounting failed."
    exit 1
fi

# Add entry to /etc/fstab if not already present
if ! grep -qs "$PARTITION $MOUNT_POINT" /etc/fstab; then
    echo "$PARTITION $MOUNT_POINT ext4 defaults,nofail 0 2" | sudo tee -a /etc/fstab
fi

echo "Disk initialization complete."