**Problem Statement**  
SSDs suffer from a “semantic gap” where device controllers remain unaware of application-level data lifetimes. This causes the “log-on-log” problem: redundant garbage collection (GC) at both the filesystem and device levels, which inflates the Write Amplification Factor (WAF) and induces latency spikes. In production caches like Meta’s CacheLib, intermixing small, hot objects with large, sequential logs typically forces a 50% capacity underutilization to maintain performance. While Zoned Namespaces (ZNS) and Flexible Data Placement (FDP) offer architectural solutions, empirical comparisons of ZNS’s strict host-side management versus FDP’s hint-based simplicity remain scarce in current literature.  
**Challenges**

* **Hardware Scarcity:** Limited availability of physical ZNS/FDP hardware requires high-fidelity emulation via tools like FEMU or FDPVirt+.  
* **Software Tax:** ZNS mandates radical stack changes, including specialized backends like ZenFS or log-structured filesystems (F2FS).  
* **I/O Bottlenecks:** Standard POSIX APIs often bottleneck next-gen NVMe throughput, requiring high-performance paths like *io\_uring* or *xNVMe*.  
* **Stream Segregation:** Identifying optimal data segregation policies without manually rewriting application I/O logic is technically complex.

**Proposed Solution**  
I will implement a benchmarking framework to evaluate ZNS and FDP side-by-side using 2025 research as a baseline. I will utilize the *Valet* shim layer approach to intercept application calls and inject placement hints non-invasively. For ZNS, the system will use a ZenFS-based backend to manage sequential zones. For FDP, I will utilize NVMe Data Placement Directives to tag writes based on object size and predicted lifetime. This comparison will quantify the trade-off between the explicit control of ZNS and the implementation ease of FDP for cloudscale caching.  
**The evaluation** will utilize CloudLab Utah’s *d760* nodes (PCIe 5.0 NVMe) or *c6525-100g* nodes for high-bandwidth experimentation. To model next-gen interfaces, I will deploy the FDPVirt+ emulator (IEEE Access 2025\) and FEMU for ZNS. Benchmarks will include *fio* for raw device-level throughput and RocksDB/CacheLib for application-level performance. I will replay production traces from Meta and Twitter to measure the Device-level WAF (DLWA), aiming for an ideal value of \~1, alongside P99 tail latency and throughput under 80%+ capacity utilization.

* **75% Goal:** Deploy the CloudLab environment on *d760* nodes with both ZNS (ZenFS) and FDP (FDPVirt+) functional. Conduct initial *fio* tests to verify WAF reduction compared to conventional block devices.  
* **100% Goal:** Profiles RocksDB, MongoDB, and CacheLib across both interfaces. Construct a comprehensive result matrix comparing ZNS and FDP performance across various hardware tiers (SATA, PCIe 4.0, and PCIe 5.0) and workloads.  
* **125% Goal:** Extend the framework by implementing an eBPF-based “Auto-Placement” module. This module will trace kernel-level file activities to automatically assign FDP Placement Identifiers (PIDs) or ZNS zones based on real-time lifetime detection.

**References**
1. [Mooncake: Trading More Storage for Less Computation — A KVCache-centric Architecture for Serving LLM Chatbot (FAST ‘25) Ruoyu Qin et al.](https://www.usenix.org/conference/fast25/presentation/qin)  
2. [Towards Efficient Flash Caches with Emerging NVMe Flexible Data Placement SSDs (EuroSys ‘25) Allison et al.](https://arxiv.org/abs/2503.11665)  
3. [Fast Cloud Storage for AI Jobs via Grouped I/O API with Transparent Read/Write Optimizations (FAST ‘26) Hao et al.](https://www.usenix.org/system/files/fast26-hao.pdf)
4. [Valet: Efficient Data Placement on Modern SSDs (SoCC ‘25) Devashish R. Purandare et al.](https://arxiv.org/abs/2501.00977)
5. [FDPVirt+: Emulated Flexible Data Placement for Sustainable SSDs (IEEE Access 2025\) Joonyeop Park and Hyeonsang Eom](https://ieeexplore.ieee.org/document/11311999)  
6. [ZNS: Avoiding the Block Interface Tax for Flash-based SSDs (USENIX ATC ‘21) Matias Bjørling et al](https://www.usenix.org/conference/atc21/presentation/bjorling).  
7. [ZNS+: Advanced Zoned Namespace Interface for Supporting In-Storage Zone Compaction (OSDI ‘21) Kyuhwa Han et al.](https://www.usenix.org/conference/osdi21/presentation/han)  
8. [RAIZN: Redundant Array of Independent Zoned Namespaces (ASPLOS ‘23) Thomas Kim et al.](https://dl.acm.org/doi/10.1145/3575693.3575746)  
9. [Don’t Be a Blockhead: Zoned Namespaces Make Work on Conventional SSDs Obsolete (HotOS ‘21) Theano Stavrinos et al.](https://sigops.org/s/conferences/hotos/2021/papers/hotos21-s07-stavrinos.pdf)  
10. [Preparation Meets Opportunity: Enhancing Data Preprocessing for ML Training With Seneca (FAST '26) Omkar Desai et al.](https://www.usenix.org/conference/fast26/presentation/desai)

