# CS2640 Final Checkpoint: NVMe Storage Benchmarking — Conventional vs ZNS vs FDP

## 1. Evolution from Midterm to Final

The midterm (75%) demonstrated ZNS vs FDP protocol-level behavior using synthetic `fio` traces inside a Dockerized QEMU emulation environment. While the emulation validated that both ZNS and FDP NVMe namespaces achieve near-ideal Write Amplification Factors (WAF ≈ 1.0), the synthetic workloads and software-emulated NVMe devices introduced performance ceilings that obscured real-world application behavior.

For the 100% milestone, we made three critical advancements:

1. **Moved to CloudLab bare-metal infrastructure** — deployed on Utah CloudLab `c6620` nodes with physical Micron 7450 800GB NVMe SSDs (PCIe Gen4) and KVM hardware virtualization.
2. **Replaced synthetic fio traces with real database engines** — RocksDB (`db_bench`), MongoDB (YCSB), and CacheLib (`cachebench`) provide authentic application-level I/O patterns.
3. **Dual-mode benchmarking** — Phase 1 runs databases directly on physical NVMe (baseline), Phase 2 runs the same workloads inside a KVM-accelerated QEMU VM against emulated ZNS and FDP devices backed by the real NVMe SSDs.

### Why QEMU Emulation for ZNS/FDP?

No CloudLab node type has NVMe drives with native ZNS or FDP support. These are specialty protocol extensions supported only by specific enterprise drives (e.g., WD Ultrastar DC ZN540 for ZNS, Samsung PM1743 for FDP) that are not deployed in any CloudLab cluster. QEMU's NVMe emulation provides protocol-accurate ZNS and FDP namespaces, and with KVM acceleration on bare-metal x86, the performance overhead is minimal — allowing meaningful comparison of protocol-level behavior under real database workloads.

## 2. CloudLab Infrastructure

### Hardware: `c6620` (Utah)

| Component | Specification |
|-----------|---------------|
| **CPU** | 28-core Intel Xeon Gold 5512U at 2.1GHz (Emerald Rapids) |
| **Memory** | 128GB DDR5-5600 ECC |
| **Storage** | 2× 800GB Mixed-use Gen4 NVMe SSD |
| **Network** | 25Gb + 100Gb Ethernet |
| **OS** | Ubuntu 22.04 LTS |

### Benchmarking Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    CloudLab c6620 Node                          │
│                                                                 │
│  Phase 1: NATIVE                   Phase 2: EMULATED            │
│  ┌──────────────────┐              ┌────────────────────────┐   │
│  │ db_bench / YCSB  │              │     QEMU/KVM VM        │   │
│  │ cachebench       │              │ ┌──────────────────┐   │   │
│  │                  │              │ │ db_bench / fio   │   │   │
│  │   ↓ direct I/O   │              │ │                  │   │   │
│  │ ┌──────────────┐ │              │ │ ↓ io_uring_cmd   │   │   │
│  │ │ Physical     │ │              │ │ ┌──┐ ┌──┐ ┌────┐│   │   │
│  │ │ NVMe SSD     │ │              │ │ │ZNS│ │FDP│ │Conv││   │   │
│  │ │ Micron 7450  │ │              │ │ └──┘ └──┘ └────┘│   │   │
│  │ └──────────────┘ │              │ └──────────────────┘   │   │
│  └──────────────────┘              │   ↓ backed by files    │   │
│                                    │ ┌──────────────────┐   │   │
│                                    │ │ Physical NVMe    │   │   │
│                                    │ └──────────────────┘   │   │
│                                    └────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## 3. Workload Descriptions

### RocksDB (`db_bench`)

RocksDB is Meta's high-performance embedded key-value store built on a Log-Structured Merge-tree (LSM) architecture. We run 5 standard `db_bench` workloads:

| Workload | Description | I/O Pattern |
|----------|-------------|-------------|
| `fillseq` | Sequential bulk load of 5M keys | Sequential writes |
| `fillrandom` | Random insertion of 5M keys | Random writes |
| `readrandom` | Point lookups on filled database | Random reads |
| `readwhilewriting` | Concurrent reads + background writes | Mixed OLTP |
| `overwrite` | Update existing keys in-place | Random writes (WAF stress) |

Configuration: 1KB values, Snappy compression, Bloom filters (10 bits/key), direct I/O enabled, 8 threads.

### MongoDB (YCSB)

MongoDB 7.0 with the WiredTiger storage engine running standard Yahoo Cloud Serving Benchmark workloads:

| Workload | Read/Write Ratio | Pattern |
|----------|-------------------|---------|
| YCSB-A | 50% Read / 50% Update | Update-heavy |
| YCSB-B | 95% Read / 5% Update | Read-mostly |
| YCSB-C | 100% Read | Read-only |
| YCSB-F | 50% Read / 50% Read-Modify-Write | Transactional |

Configuration: 1M records loaded, 500K operations per run, 8 client threads, Snappy compression on WiredTiger.

### CacheLib (`cachebench`)

Meta's CacheLib is the production caching engine used across Meta's CDN, social graph, and key-value infrastructure. We run 3 workload profiles using the Navy (NVM) SSD cache backend:

| Workload | Object Size | R/W Ratio | Description |
|----------|-------------|-----------|-------------|
| Graph Cache | 64–256 B | 80/15/5 (get/set/del) | Social graph caching, Zipf α=1.2 |
| CDN Cache | 1–64 KB | 30/65/5 (get/set/del) | Media/CDN edge cache, Zipf α=0.9 |
| KV Store | 64 B–16 KB | 50/40/10 (get/set/del) | General KV store, Zipf α=1.0 |

## 4. Results

> **Note:** Results will be populated after running the benchmarks on the CloudLab node. Run `sudo ./benchmarks/run_all.sh` and the tables below will be filled from the output logs.

### Phase 1: Native NVMe Results

#### RocksDB

| Workload | Throughput (ops/sec) | Avg Latency (μs) | P99 Latency (μs) |
|----------|---------------------|-------------------|-------------------|
| fillseq | *pending* | *pending* | *pending* |
| fillrandom | *pending* | *pending* | *pending* |
| readrandom | *pending* | *pending* | *pending* |
| readwhilewriting | *pending* | *pending* | *pending* |
| overwrite | *pending* | *pending* | *pending* |

#### MongoDB YCSB

| Workload | Throughput (ops/sec) | Avg Read Lat (μs) | Avg Write Lat (μs) | P99 Lat (μs) |
|----------|---------------------|--------------------|---------------------|---------------|
| YCSB-A (50/50) | *pending* | *pending* | *pending* | *pending* |
| YCSB-B (95/5) | *pending* | *pending* | *pending* | *pending* |
| YCSB-C (100/0) | *pending* | *pending* | *pending* | *pending* |
| YCSB-F (RMW) | *pending* | *pending* | *pending* | *pending* |

#### CacheLib

| Workload | Throughput (ops/sec) | Hit Rate (%) | Avg Latency (μs) | P99 Latency (μs) |
|----------|---------------------|--------------|-------------------|-------------------|
| Graph Cache | *pending* | *pending* | *pending* | *pending* |
| CDN Cache | *pending* | *pending* | *pending* | *pending* |
| KV Store | *pending* | *pending* | *pending* | *pending* |

### Phase 2: Emulated ZNS vs FDP vs Conventional

#### Protocol-Level Comparison (fio)

| Metric | ZNS | FDP | Conventional |
|--------|-----|-----|-------------|
| Sequential Write IOPS | *pending* | *pending* | *pending* |
| Random Write IOPS | *pending* | *pending* | *pending* |
| Write Bandwidth (MB/s) | *pending* | *pending* | *pending* |
| WAF (Host/Media writes) | *pending* | *pending* | *pending* |

#### RocksDB db_bench — ZNS vs FDP vs Conventional

| Workload | Conv (ops/s) | FDP (ops/s) | ZNS (ops/s) | FDP WAF | ZNS WAF |
|----------|-------------|-------------|-------------|---------|---------|
| fillseq | *pending* | *pending* | *pending* | *pending* | *pending* |
| fillrandom | *pending* | *pending* | *pending* | *pending* | *pending* |
| readrandom | *pending* | *pending* | *pending* | *pending* | *pending* |
| overwrite | *pending* | *pending* | *pending* | *pending* | *pending* |

### NVMe SMART Data (Physical Drive)

| Metric | Pre-Benchmark | Post-Benchmark |
|--------|---------------|----------------|
| Data Units Written | *pending* | *pending* |
| Data Units Read | *pending* | *pending* |
| Host Writes | *pending* | *pending* |
| Media Writes | *pending* | *pending* |

## 5. Comprehensive Result Matrix

The final deliverable is a cross-cutting comparison across all three storage engines and NVMe interface types:

| Metric | RocksDB (Native) | MongoDB (Native) | CacheLib (Native) | RocksDB (FDP) | RocksDB (ZNS) |
|--------|-------------------|------------------|--------------------|---------------|---------------|
| Peak Write Throughput | *pending* | *pending* | *pending* | *pending* | *pending* |
| Peak Read Throughput | *pending* | *pending* | *pending* | *pending* | *pending* |
| Write P99 Latency | *pending* | *pending* | *pending* | *pending* | *pending* |
| Read P99 Latency | *pending* | *pending* | *pending* | *pending* | *pending* |
| WAF | N/A (conventional) | N/A | N/A | *pending* | *pending* |

### Observations

*To be filled after benchmark execution.*

Key areas of analysis:
- **ZNS vs FDP WAF**: Comparing write amplification under identical database workloads
- **Protocol overhead**: Performance delta between native conventional NVMe and emulated devices
- **I/O amplification**: RocksDB's LSM compaction vs MongoDB's WiredTiger B-tree vs CacheLib's Navy log-structured cache
- **Latency distribution**: Tail latency (P99) differences under different read/write ratios
- **Throughput scaling**: How each engine utilizes NVMe parallelism with 8 threads
- **Device utilization**: NVMe SMART data showing total host vs media writes

## 6. ZNS and FDP Analysis

### ZNS (Zoned Namespaces)

ZNS divides the NVMe namespace into sequential write zones, eliminating the drive's internal garbage collection and putting data placement responsibility on the host. This is ideal for:
- **RocksDB**: LSM-tree SSTables are immutable, sequential files — they map naturally to zones
- **CacheLib**: Navy's log-structured allocator writes sequentially to large regions

### FDP (Flexible Data Placement)

FDP provides hint-based data placement using Reclaim Unit Handles (RUHs), allowing applications to co-locate related data without the strict sequential-write constraint of ZNS:
- **RocksDB**: Can separate WAL, L0 flushes, and compaction output into different RUHs
- **MongoDB**: Can separate WiredTiger journal from data checkpoints

### Why Both Matter

ZNS offers maximum control but requires application redesign (all writes must be sequential within a zone). FDP offers nearly the same WAF benefit with backward-compatible random writes — making it a more practical near-term solution for existing applications.

---

### References
[1] Cooper, B. F., Silberstein, A., Tam, E., Ramakrishnan, R., & Sears, R. (2010). Benchmarking cloud serving systems with YCSB. *Proceedings of the 1st ACM symposium on Cloud computing*.

[2] Berg, B., et al. (2020). The CacheLib Caching Engine: Design and Experiences at Scale. *USENIX OSDI*.

[3] Dong, S., Callaghan, M., Galanis, L., et al. (2017). Optimizing Space Amplification in RocksDB. *CIDR*.

[4] Bjørling, M., et al. (2021). ZNS: Avoiding the Block Interface Tax for Flash-based SSDs. *USENIX ATC*.

[5] Samsung. (2023). Flexible Data Placement (FDP) Technical Brief. NVMe TP 4146.
