#!/bin/bash
set -e

echo "======================================"
echo " Starting Benchmarks Inside QEMU Guest"
echo "======================================"

export DEBIAN_FRONTEND=noninteractive

# Point path and library loader to the 9p mount where the host dropped the binaries
export PATH=/host/bin:$PATH
export LD_LIBRARY_PATH=/host/lib:$LD_LIBRARY_PATH

echo "Runtime dependencies sourced from /host directly!"

# Verify NVMe devices mounted by QEMU
nvme list

mkdir -p /host/results

# Target devices as instantiated by QEMU in entrypoint.sh:
# /dev/nvme0n1 is ZNS
# /dev/nvme1n1 is FDP

echo "--- Running MongoDB (YCSB) Profile on ZNS ---"
fio /host/mongodb_profile.fio --filename=/dev/ng0n1 --zonemode=zbd | tee /host/results/mongodb_zns.log

echo "--- Running MongoDB (YCSB) Profile on FDP ---"
fio /host/mongodb_profile.fio --filename=/dev/ng1n1 --fdp=1 | tee /host/results/mongodb_fdp.log

echo "--- FDP Statistics After MongoDB Workload ---"
nvme fdp status /dev/nvme1n1 > /host/results/fdp_status_mongodb.txt || true
nvme fdp stats -e 1 /dev/nvme1n1 > /host/results/fdp_stats_mongodb.txt || true

echo "--- Running CacheLib Profile on ZNS ---"
fio /host/cachelib_profile.fio --filename=/dev/ng0n1 --zonemode=zbd | tee /host/results/cachelib_zns.log

echo "--- Running CacheLib Profile on FDP ---"
fio /host/cachelib_profile.fio --filename=/dev/ng1n1 --fdp=1 | tee /host/results/cachelib_fdp.log

echo "--- FDP Statistics After CacheLib Workload ---"
nvme fdp status /dev/nvme1n1 > /host/results/fdp_status_cachelib.txt || true
nvme fdp stats -e 1 /dev/nvme1n1 > /host/results/fdp_stats_cachelib.txt || true

echo "Benchmarks completed successfully! Data flushed to host."
sync
