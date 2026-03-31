#!/bin/bash
# run_fio_zns.sh - Example fio script for Zoned Namespaces (ZNS)
# IMPORTANT: Replace TARGET_DEV with your actual ZNS or emulated ZBD device (e.g., /dev/nvme1n1)

TARGET_DEV="/dev/nvme1n1"

if [ ! -b "$TARGET_DEV" ]; then
    echo "Error: Device $TARGET_DEV does not exist. Please update TARGET_DEV in the script."
    exit 1
fi

echo "Running ZNS fio benchmark on $TARGET_DEV..."
sudo fio --name=zns_test \
         --filename=$TARGET_DEV \
         --direct=1 \
         --zonemode=zbd \
         --ioengine=libaio \
         --rw=write \
         --bs=64k \
         --size=1G \
         --group_reporting
