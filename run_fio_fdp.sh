#!/bin/bash
# run_fio_fdp.sh - Example fio script for Flexible Data Placement (FDP)
# IMPORTANT: Replace TARGET_DEV with your actual FDP emulated device (e.g., /dev/nvme1n1)

TARGET_DEV="/dev/nvme1n1"

if [ ! -b "$TARGET_DEV" ]; then
    echo "Error: Device $TARGET_DEV does not exist. Please update TARGET_DEV in the script."
    exit 1
fi

echo "Running FDP fio benchmark on $TARGET_DEV..."
sudo fio --name=fdp_test \
         --filename=$TARGET_DEV \
         --direct=1 \
         --ioengine=io_uring_cmd \
         --cmd_type=nvme \
         --fdp=1 \
         --fdp_pli=0,1 \
         --rw=randwrite \
         --bs=4k \
         --size=1G \
         --group_reporting
