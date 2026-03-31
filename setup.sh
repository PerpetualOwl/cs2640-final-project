#!/bin/bash
# setup.sh - CloudLab initialization script for 75% experiment (ZNS ZenFS & FDPVirt+)
# This script is executed automatically as root when the CloudLab node boots.

# Create log directory and redirect all output to a log file for debugging
mkdir -p /local/logs
exec > /local/logs/setup.log 2>&1

echo "Starting setup script..."

# Update and install dependencies
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y pciutils bc nvme-cli \
        build-essential cmake git pkg-config \
        libgflags-dev libsnappy-dev zlib1g-dev libbz2-dev liblz4-dev libzstd-dev \
        fio sysfsutils linux-headers-$(uname -r) \
        autoconf automake libtool

# Install libzbd from source (required for ZenFS)
echo "Building libzbd..."
cd /local
git clone https://github.com/westerndigitalcorporation/libzbd.git
cd libzbd
./autogen.sh
./configure
make -j$(nproc)
make install
ldconfig

# Build FDPVirt+
echo "Building FDPVirt+..."
cd /local
git clone https://github.com/junyupp/FDPVirt.git
cd FDPVirt
make -j$(nproc)
insmod nvmevirt.ko
echo "FDPVirt+ module loaded."

# Emulate FDP namespace (using commands from documentation)
# Note: You may need to adjust device name (/dev/nvme0) depending on actual topology
if [ -c /dev/nvme0 ]; then
    echo "Configuring FDP on /dev/nvme0..."
    nvme set-feature /dev/nvme0 -f 0x1d --value 1 -c 0x201 -s || true
    nvme create-ns /dev/nvme0 -c 0x1bf1f72b0 -s 0x1bf1f72b0 -n 2 -p 2,5 || true
fi

# Build RocksDB with ZenFS
echo "Building RocksDB and ZenFS..."
cd /local
git clone --recurse-submodules https://github.com/facebook/rocksdb.git
cd rocksdb
git clone https://github.com/westerndigitalcorporation/zenfs plugin/zenfs
mkdir build && cd build
cmake -DWITH_ZENFS=ON ..
make -j$(nproc) zenfs_util db_bench

# Make helper scripts executable
chmod +x /local/repository/run_fio_zns.sh
chmod +x /local/repository/run_fio_fdp.sh

echo "Setup completed successfully!"
