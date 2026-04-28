# CloudLab Setup & Running Instructions

This repository is structured as a **CloudLab repository-based profile**. When you instantiate it, CloudLab will automatically clone this repository to `/local/repository` on the provisioned node and execute the `setup.sh` startup script.

---

## Prerequisites
- A [CloudLab account](https://www.cloudlab.us/signup.php) and membership in a project
- SSH key configured in your CloudLab account

---

## Step 1: Create the CloudLab Profile

1. Log in to [CloudLab](https://www.cloudlab.us/)
2. Navigate to **Experiments** → **Create Experiment Profile**
3. Select **Git Repository** and paste this repository's URL:
   ```
   https://github.com/PerpetualOwl/cs2640-final-project
   ```
4. CloudLab will detect the `profile.py` file in the root directory
5. Give the profile a name (e.g., `cs2640-nvme-bench`) and save it

> **Alternatively**, if someone has already created the profile, you can use the shared profile link directly.

---

## Step 2: Instantiate an Experiment

1. Go to **Experiments** → **Start Experiment**
2. Select the profile you just created
3. In the **Parameterize** step:
   - **Hardware Type**: `c6620` (default — Utah, 2× Micron 7450 800GB NVMe SSDs)
   - **OS Image**: Ubuntu 22.04 (default)
4. In the **Finalize** step, choose the **Utah** cluster
5. Click **Create** and wait for provisioning (~10-15 minutes for node allocation)

> **Note**: If `c6620` nodes are unavailable, try `d7525`, `c6525-100g`, or `d760`. All must have NVMe SSDs.

---

## Step 3: Wait for Setup to Complete

The `setup.sh` script runs automatically on first boot. It will:
1. Install system packages (build tools, libraries)
2. Detect and format the NVMe SSD at `/mnt/nvme`
3. Compile RocksDB and `db_bench` from source
4. Install MongoDB 7.0 Community Edition
5. Download YCSB 0.17.0
6. Build CacheLib and `cachebench`

### Monitor setup progress:
```bash
# SSH into the node (hostname from CloudLab experiment page)
ssh your_username@node.utah.cloudlab.us

# Watch the setup log in real time
tail -f /local/logs/setup.log

# Wait for the message:
# "Setup completed successfully!"
```

> **Expected duration**: 15-30 minutes depending on build times. RocksDB and CacheLib compilation are the longest steps.

---

## Step 4: Verify the Environment

```bash
# Check NVMe device is mounted
df -h /mnt/nvme

# Verify tools are installed
db_bench --version
mongod --version
which cachebench

# Check NVMe device details
sudo nvme list
sudo nvme smart-log /dev/nvme0n1
```

---

## Step 5: Run Benchmarks

### Run All Benchmarks (Recommended)
```bash
cd /local/repository
sudo ./benchmarks/run_all.sh
```

This runs all three database benchmarks sequentially:
1. **RocksDB** — `db_bench` with 5 workload profiles
2. **MongoDB** — YCSB Workloads A, B, C, F
3. **CacheLib** — `cachebench` with 3 cache workload profiles

### Run Individual Benchmarks
```bash
# RocksDB only
sudo ./benchmarks/rocksdb/run_rocksdb.sh /mnt/nvme /local/repository/results

# MongoDB only
sudo ./benchmarks/mongodb/run_mongodb.sh /mnt/nvme /local/repository/results

# CacheLib only
sudo ./benchmarks/cachelib/run_cachelib.sh /mnt/nvme /local/repository/results
```

---

## Step 6: Collect Results

All benchmark results are written to `/local/repository/results/`:

```
results/
├── system_info.txt              # CPU, memory, NVMe details
├── nvme_smart_post.txt          # NVMe SMART data after all benchmarks
├── rocksdb_full.log             # Complete RocksDB output
├── rocksdb/
│   ├── fillseq.log              # Sequential write benchmark
│   ├── fillrandom.log           # Random write benchmark
│   ├── readrandom.log           # Random read benchmark
│   ├── readwhilewriting.log     # Mixed read/write benchmark
│   └── overwrite.log            # Update-heavy benchmark
├── mongodb_full.log             # Complete MongoDB output
├── mongodb/
│   ├── mongod.log               # MongoDB server log
│   ├── workloada_load.log       # YCSB-A load phase
│   ├── workloada_run.log        # YCSB-A run phase (50/50 R/W)
│   ├── workloadb_run.log        # YCSB-B run phase (95/5 R/W)
│   ├── workloadc_run.log        # YCSB-C run phase (100% Read)
│   ├── workloadf_run.log        # YCSB-F run phase (Read-Modify-Write)
│   └── wiredtiger_stats.json    # WiredTiger engine statistics
├── cachelib_full.log            # Complete CacheLib output
└── cachelib/
    ├── graph_cache.log          # Small object, read-heavy cache
    ├── cdn_cache.log            # Large object, write-heavy cache
    └── kv_store.log             # Mixed KV store workload
```

### Copy Results Off the Node
```bash
# From your local machine:
scp -r your_username@node.utah.cloudlab.us:/local/repository/results ./results
```

> **Important**: CloudLab experiments expire! Copy your results before the experiment terminates.

---

## Troubleshooting

### Setup script failed
```bash
# Check the full log
less /local/logs/setup.log

# Re-run setup manually
sudo /local/repository/setup.sh
```

### NVMe not detected
```bash
# List all block devices
lsblk
# Check NVMe subsystem
sudo nvme list
# Check dmesg for NVMe errors
dmesg | grep -i nvme
```

### MongoDB won't start
```bash
# Check if another mongod is running
pgrep mongod
# Kill stale processes
sudo killall mongod
# Check the log
cat /local/repository/results/mongodb/mongod.log
```

### CacheLib build failed
CacheLib has complex dependencies. If the build fails:
```bash
# Check the setup log for errors
grep -i "error\|fail" /local/logs/setup.log

# Try rebuilding manually
cd /local/build/CacheLib
sudo ./contrib/build.sh -j $(nproc) -d
```

---

## Hardware Compatibility

This profile works on any CloudLab node with NVMe SSDs. Tested/recommended types:

| Node Type | Location | NVMe | Notes |
|-----------|----------|------|-------|
| **c6620** | Utah | 2× Micron 7450 800GB | **Default**, PCIe Gen4 |
| d7525 | Utah | NVMe present | AMD EPYC |
| c6525-100g | Clemson | NVMe present | AMD EPYC, 100G NICs |
| d760 | Utah | NVMe PCIe 5.0 | Newest hardware |
