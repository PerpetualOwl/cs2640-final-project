# 75% Experiment CloudLab Setup Instructions

## Step 1: Instantiate the Profile
1. Go to the [CloudLab Portal](https://www.cloudlab.us/) and log in.
2. Click **Experiments** -> **Start Experiment**.
3. Go to the **Profile Selection** step.
4. Click **Change Profile** -> **Instantiate Repository**.
5. Paste the GitHub URL for your repository containing these files. CloudLab will automatically read the `profile.py` file.
6. In the **Parameterize** step, choose your desired hardware type (default: `c6525-100g`). There are many options available across Utah, Clemson, and Wisconsin clusters in case the default nodes are reserved.
7. Click **Finish/Instantiate** and wait for the CloudLab node to provision (this takes about 10-15 minutes).

## Step 2: Ensure Node Setup Completes
Because FDPVirt+ and ZenFS/RocksDB do not have precompiled binaries available, the node will download and compile them from source during startup.

1. Once the node is ready (green checkmark), SSH into the node from the CloudLab UI or using your terminal:
   ```bash
   ssh your_username@node_hostname
   ```
2. Monitor the setup progress by checking the log file:
   ```bash
   tail -f /local/logs/setup.log
   ```
3. Wait until you see `Setup completed successfully!` at the end of the log before proceeding to benchmarking.

## Step 3: Device Verification & Benchmarking
1. Check your available NVMe namespaces to find the target devices:
   ```bash
   sudo nvme list
   ```
2. Your repository's contents are located in `/local/repository`. Navigate to it:
   ```bash
   cd /local/repository
   ```
3. **Important:** Open `run_fio_zns.sh` and `run_fio_fdp.sh` in an editor (like `vim` or `nano`) and ensure `TARGET_DEV` matches the NVMe device handles output by `nvme list`.
4. Run the benchmarks:
   ```bash
   # ZNS Benchmark
   sudo ./run_fio_zns.sh
   
   # FDP Benchmark
   sudo ./run_fio_fdp.sh
   ```
5. Check FDP device WAF and stats:
   ```bash
   sudo nvme fdp stats /dev/nvmeXnY
   ```
