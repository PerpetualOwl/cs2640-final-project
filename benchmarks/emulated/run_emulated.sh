#!/bin/bash
#
# run_emulated.sh — Run all database benchmarks inside QEMU VM against
#                   emulated ZNS, FDP, and conventional NVMe devices.
#
# This script:
#   1. Starts the QEMU VM with KVM (ZNS + FDP + conventional NVMe)
#   2. Installs pre-compiled tools from the host into the VM
#   3. Runs db_bench, YCSB, and cachebench against each NVMe type
#   4. Collects results and NVMe stats
#   5. Shuts down the VM
#
# Usage: ./run_emulated.sh [results_dir]
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RESULTS_DIR="${1:-/local/repository/results/emulated}"
SSH_PORT=2222

mkdir -p "$RESULTS_DIR"

echo "============================================"
echo " Emulated ZNS/FDP Benchmarks"
echo " $(date)"
echo "============================================"

# -----------------------------------------------------------------------
# 1. Start the QEMU VM
# -----------------------------------------------------------------------
echo "[1/5] Starting QEMU VM ..."
bash "$SCRIPT_DIR/setup_qemu_vm.sh" start

# Helper to run commands in the VM
vm() {
    ssh -q -o StrictHostKeyChecking=no -p $SSH_PORT bench@localhost "$@"
}

# Wait for VM to be fully ready
echo "Waiting for VM to be fully initialized ..."
for i in $(seq 1 60); do
    if vm "test -f /tmp/vm_ready" 2>/dev/null; then
        break
    fi
    sleep 5
done

# -----------------------------------------------------------------------
# 2. Verify emulated devices
# -----------------------------------------------------------------------
echo "[2/5] Verifying emulated NVMe devices ..."
vm "sudo nvme list" | tee "$RESULTS_DIR/nvme_devices.txt"
vm "lsblk" | tee "$RESULTS_DIR/lsblk.txt"
echo ""

# Map device names (order: ZNS=nvme0, FDP=nvme1, Conventional=nvme2)
ZNS_DEV="/dev/nvme0n1"
FDP_DEV="/dev/nvme1n1"
CONV_DEV="/dev/nvme2n1"

# Verify ZNS zones
echo "Verifying ZNS zones ..."
vm "sudo nvme zns report-zones $ZNS_DEV -d 5" | tee "$RESULTS_DIR/zns_zones.txt" || true

# Verify FDP config
echo "Verifying FDP configuration ..."
vm "sudo nvme fdp status $FDP_DEV" | tee "$RESULTS_DIR/fdp_config.txt" || true

# -----------------------------------------------------------------------
# 3. Prepare filesystems in the VM
# -----------------------------------------------------------------------
echo "[3/5] Preparing filesystems on emulated devices ..."

# Mount host share
vm "sudo mkdir -p /host && sudo mount -t 9p -o trans=virtio hostshare /host 2>/dev/null" || true

# Create filesystems on conventional and FDP devices
vm "sudo mkfs.ext4 -F $CONV_DEV && sudo mkdir -p /mnt/conv && sudo mount -o discard,noatime $CONV_DEV /mnt/conv && sudo chmod 777 /mnt/conv"
vm "sudo mkfs.ext4 -F $FDP_DEV && sudo mkdir -p /mnt/fdp && sudo mount -o discard,noatime $FDP_DEV /mnt/fdp && sudo chmod 777 /mnt/fdp"

# ZNS needs a zone-aware filesystem or direct access — use f2fs if available, else direct fio
vm "sudo mkfs.f2fs -f -m $ZNS_DEV && sudo mkdir -p /mnt/zns && sudo mount -o discard,noatime $ZNS_DEV /mnt/zns && sudo chmod 777 /mnt/zns" 2>/dev/null || {
    echo "NOTE: f2fs not available for ZNS. Will use fio with io_uring_cmd for direct zone access."
}

# -----------------------------------------------------------------------
# 4. Run benchmarks
# -----------------------------------------------------------------------
echo "[4/5] Running benchmarks ..."

# --- 4a. fio direct I/O benchmarks for protocol comparison ---
echo ""
echo "=== fio protocol-level benchmarks ==="

# ZNS: Sequential write (zone append)
echo "--- fio: ZNS Sequential Write ---"
vm "sudo fio --name=zns_seqwrite \
    --filename=$ZNS_DEV --direct=1 --ioengine=io_uring_cmd \
    --cmd_type=nvme --rw=write --bs=128k \
    --iodepth=32 --numjobs=1 --size=4G \
    --output-format=json" 2>&1 | tee "$RESULTS_DIR/fio_zns_seqwrite.json"

# FDP: Random write with placement hints
echo "--- fio: FDP Random Write ---"
vm "sudo fio --name=fdp_randwrite \
    --filename=$FDP_DEV --direct=1 --ioengine=io_uring_cmd \
    --cmd_type=nvme --rw=randwrite --bs=4k \
    --iodepth=32 --numjobs=4 --size=4G \
    --fdp=1 --fdp_pli=0,1,2,3 \
    --output-format=json" 2>&1 | tee "$RESULTS_DIR/fio_fdp_randwrite.json"

# Conventional: Random write (baseline)
echo "--- fio: Conventional Random Write ---"
vm "sudo fio --name=conv_randwrite \
    --filename=$CONV_DEV --direct=1 --ioengine=io_uring_cmd \
    --cmd_type=nvme --rw=randwrite --bs=4k \
    --iodepth=32 --numjobs=4 --size=4G \
    --output-format=json" 2>&1 | tee "$RESULTS_DIR/fio_conv_randwrite.json"

# Capture FDP stats after fio
echo "--- FDP Stats after fio ---"
vm "sudo nvme fdp stats $FDP_DEV" | tee "$RESULTS_DIR/fdp_stats_post_fio.txt" || true

# --- 4b. RocksDB db_bench (if available in VM) ---
echo ""
echo "=== RocksDB db_bench on emulated devices ==="

# Copy db_bench from host if built
vm "test -f /usr/local/bin/db_bench" 2>/dev/null || {
    vm "sudo cp /host/benchmarks/emulated/../../build/rocksdb/build/db_bench /usr/local/bin/ 2>/dev/null" || {
        echo "NOTE: db_bench not available in VM. Install manually or use host-built binary."
    }
}

for DEV_LABEL in conv fdp; do
    MNT="/mnt/$DEV_LABEL"
    echo "--- db_bench on $DEV_LABEL ($MNT) ---"
    vm "rm -rf $MNT/rocksdb_bench $MNT/rocksdb_wal; mkdir -p $MNT/rocksdb_bench $MNT/rocksdb_wal" || continue

    for WORKLOAD in fillseq fillrandom readrandom overwrite; do
        echo "  > $WORKLOAD on $DEV_LABEL"
        vm "db_bench --benchmarks=$WORKLOAD \
            --db=$MNT/rocksdb_bench --wal_dir=$MNT/rocksdb_wal \
            --num=1000000 --value_size=1024 --threads=4 \
            --compression_type=snappy \
            --write_buffer_size=67108864 \
            --use_direct_io_for_flush_and_compaction \
            --use_direct_reads \
            $([ '$WORKLOAD' != 'fillseq' ] && [ '$WORKLOAD' != 'fillrandom' ] && echo '--use_existing_db' || echo '')" \
            2>&1 | tee "$RESULTS_DIR/rocksdb_${DEV_LABEL}_${WORKLOAD}.log" || true
    done
done

# --- 4c. Capture final NVMe stats ---
echo ""
echo "=== Final NVMe Statistics ==="
echo "--- ZNS Zone Report ---"
vm "sudo nvme zns report-zones $ZNS_DEV" | tee "$RESULTS_DIR/zns_zones_final.txt" || true

echo "--- FDP Stats ---"
vm "sudo nvme fdp stats $FDP_DEV" | tee "$RESULTS_DIR/fdp_stats_final.txt" || true

echo "--- FDP Events ---"
vm "sudo nvme fdp events $FDP_DEV" | tee "$RESULTS_DIR/fdp_events.txt" || true

# -----------------------------------------------------------------------
# 5. Collect results and shutdown
# -----------------------------------------------------------------------
echo "[5/5] Collecting results ..."

# Copy any results from VM to host
vm "ls -la /mnt/conv/ /mnt/fdp/" | tee "$RESULTS_DIR/device_usage.txt" || true

echo ""
echo "============================================"
echo " Emulated Benchmarks Complete — $(date)"
echo "============================================"
echo "Results saved to: $RESULTS_DIR"
ls -la "$RESULTS_DIR"

# Don't auto-shutdown VM — user may want to inspect it
echo ""
echo "VM is still running. To stop it:"
echo "  sudo $SCRIPT_DIR/setup_qemu_vm.sh stop"
echo "To SSH into the VM:"
echo "  ssh -p $SSH_PORT bench@localhost"
