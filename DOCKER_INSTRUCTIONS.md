# Docker & QEMU Emulation Instructions

This repository contains a fully containerized emulation environment for benchmarking ZNS and FDP protocols side-by-side using QEMU User-Space virtualization. It completely avoids complex kernel dependencies and works out-of-the-box on Mac (ARM64), Windows, and Linux.

## Requirements
- Docker (or Docker Desktop on Mac/Windows)

## How It Works
Instead of requiring bare-metal NVMe drives on CloudLab, this project uses:
1. **Docker** to build `RocksDB`, `ZenFS`, and `libzbd` locally for your CPU architecture (either x86_64 or arm64). This avoids the slow compilation phases of older setups.
2. An **Entrypoint** script that spins up a lightweight QEMU Virtual Machine inside the container.
3. **QEMU NVMe Emulation** natively simulates two NVMe block devices at the PCI level:
   - `/dev/nvme0n1` (ZNS drive, using the `zoned=on` extension)
   - `/dev/nvme1n1` (FDP drive, using the `fdp=on` subsystem configuration)
4. A minimal Ubuntu Cloud image boots, runs your `run_fio_zns.sh` and `run_fio_fdp.sh` scripts against these devices, provisions ZenFS, and safely writes the output `.log` and WAF statistics to your local machine before terminating.

## Usage Guide

### 1. Build the Docker Image
To build the Docker image (this will compile RocksDB, taking roughly 10-15 minutes, and caching it locally):

```bash
docker build -t cs2640-nvme-eval .
```

### 2. Run the Benchmarks
To run the evaluation, you just need to spin up the container and mount a `results` folder so you can see the outputs:

```bash
mkdir -p results
docker run --rm -v $(pwd)/results:/workspace/results cs2640-nvme-eval
```

> **Note for Mac/Windows Users**: By default, QEMU will use `tcg` (software emulation). The output logs and benchmark performance will reflect software-bounded IOPS limits, but the **WAF reductions (Device Level Write Amplification)** behavior characteristic of ZNS/FDP will be functionally identical and measurable!

### 3. Review the Results
Once the container exits, QEMU will safely shut down and your `results` folder will contain:
- `vm_execution.log`: The STDOUT showing all `fio` benchmarks and installation commands
- Data logs generated during the testing
- `fdp_stats_after.txt`: The resultant Write Amplification/Reclaim statistics for the FDP drive
