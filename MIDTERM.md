# CS2640 Midterm Checkpoint: ZNS vs FDP Emulation Profile

## 1. CloudLab Challenges and Branching Strategy
Our initial trajectory focused heavily on targeting CloudLab's `c6525-100g` and `d760` nodes to secure bare-metal evaluation environments for emerging NVMe SSD protocols. We successfully formulated a repository-based profile provisioning system (`profile.py`) designed to quickly allocate and instantiate these servers. 

However, we rapidly encountered severe hardware availability roadblocks. The scarcity of these high-tier, specialized PCIe Gen4/5 NVMe nodes led to consistent reservation lockouts, effectively halting continuous development and testing. To mitigate this disruption, we strategically preserved all physical-node deployment infrastructure on a separate Git branch. This allows us to re-merge and execute the definitive hardware evaluations later in the semester when node availability aligns, while unblocking immediate software engineering.

## 2. Transition to Dockerized QEMU Emulation
To democratize and accelerate our test iterations across locally accessible hardware (including ARM-based macOS machines), we radically pivoted our infrastructure towards a lightweight emulation methodology. 

We engineered a unified Docker container wrapping a QEMU-driven Ubuntu 24.04 environment. QEMU's robust virtualization backends allowed us to programmatically define mathematically precise synthetic ZNS (Zoned Namespaces) and FDP (Flexible Data Placement) block devices dynamically at boot (`-device nvme-ns,zoned=on` and `-device nvme-subsys,fdp=on`). This setup provides a functionally complete, OS-agnostic testing bed capable of simulating bleeding-edge storage APIs without needing thousands of dollars in proprietary silicon.

## 3. Design Process and Execution Hurdles
The architectural journey from the physical node specification to the currently operational Docker testbed was highly iterative and required solving multiple complex technical bottlenecks:

- **Compilation OOMs:** We originally attempted to natively compile Meta's RocksDB engine alongside the Western Digital ZenFS target plugin. On memory-constrained Docker Desktop environments, C++ compilation (`cc1plus`) spanning multiple parallel threads repeatedly resulted in Out-of-Memory kernel terminations. 
- **Build Hardening:** We bypassed these crashes by strictly restricting make limits (`-j2`) and deliberately disabling heavy debug symbol injections during the CMake generation phase (`-g0 -O2`). While this stopped the crash, it artificially inflated our container build times to over 20 minutes, which crippled developer velocity.
- **Virtualization Debugging:** Executing QEMU explicitly via `TCG` (Software Emulation mode) on nested Apple Silicon architectures precipitated numerous hidden race conditions. We had to systematically debug missing host UEFI bootloaders (`qemu-efi-aarch64`), detached virtual NAT interfaces that stalled initialization daemons, and invisible serial console outputs masking critical execution errors.
- **The Zero-Compile Injection Solution:** We functionally solved the deployment latency by moving entirely away from natively installing packages over the slow emulated virtual network. We implemented a bypass script in our `Dockerfile` that packages pre-compiled binaries along with their `ldd` dynamic dependencies injected directly onto the `/workspace` 9p filesystem. This successfully reduced test spin-up times from ~15 minutes down to roughly ~3 seconds.

## 4. Application Simulation via Synthetic Workload Tracing
Rather than continuing to battle massive, monolithic C++ codebases like RocksDB, MongoDB, and CacheLib over experimental namespaces, we determined a structurally superior method of performance assessment: deterministic workload modeling.

We successfully deployed the Flexible I/O Tester (`fio`), utilizing the ultra-modern `io_uring_cmd` command framework to directly issue NVMe protocol calls without standard POSIX block interference or OS-level page cache buffering (`O_DIRECT` compatibility workarounds). We engineered two primary evaluation traces to mathematically reflect production deployments:

* **MongoDB Specification:** Modeled heavily after Yahoo Cloud Serving Benchmark (YCSB) Workload A. The trace institutes a highly relational, update-heavy interaction map characterized by a 50/50 read-write distribution across 16KB blocks, skewed toward hot documents utilizing a mathematically governed Zipfian distribution factor [1].
* **CacheLib Specification:** Modeled using Meta’s extensive CDN trace topologies. This simulates an aggressive caching node subjected to high ingress ratios (80% Writes). We configured diverse dynamic chunk splittings up to 64KB dispersed across a heavy-tailed Pareto distribution to realistically recreate the lifespan dynamics of edge-node object replacements [2].

## 5. Preliminary Emulation Results

*Disclaimer: Performance bandwidth and execution IOPS are intentionally stunted as QEMU is restricted to pure `TCG` software emulation inside the Apple Silicon Docker abstraction layer. However, relative performance proportions and FDP/ZNS placement behaviors remain structurally valid and observable against the internal QEMU subsystem logging mechanisms.*

### MongoDB Workload Profile
| Storage Architecture | Read IOPS | Write IOPS | Device-Level WAF |
| :--- | :--- | :--- | :--- |
| **ZNS** (`zonemode=zbd`) | 1,102 | 1,109 | 1.000 | 
| **FDP** (`fdp=1`, `e=1`) | 1,165 | 1,181 | 1.000 |

### CacheLib Workload Profile
| Storage Architecture | Read IOPS | Write IOPS | Device-Level WAF |
| :--- | :--- | :--- | :--- |
| **ZNS** (`zonemode=zbd`) | 339 | 1,341 | 1.000 | 
| **FDP** (`fdp=1`, `e=1`) | 324 | 1,309 | 1.000 |

**Observations**
Both ZNS and FDP successfully executed Write Amplification Factors closely approximating the theoretical ideal limit of 1.0. The FDP drive reported highly precise placement parsing (e.g., *MBMW = 387.05 MB / HBMW = 387.00 MB* directly pulled from internal runtime execution metrics). The slight metadata inflation represents standard NVMe header tracking sizes. These outputs confirm that both the direct placement emulation engine through QEMU and the structural integrity of the `fio` trace parsing are functioning perfectly prior to physical hardware validation.

---
### References
[1] Cooper, B. F., Silberstein, A., Tam, E., Ramakrishnan, R., & Sears, R. (2010). Benchmarking cloud serving systems with YCSB. *Proceedings of the 1st ACM symposium on Cloud computing*.

[2] Berg, B., et al. (2020). The CacheLib Caching Engine: Design and Experiences at Scale. *USENIX Symposium on Operating Systems Design and Implementation (OSDI)*.
