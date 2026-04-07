FROM ubuntu:24.04

# Prevent interactive prompts during apt
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    qemu-system-x86 qemu-system-arm qemu-system-aarch64 qemu-efi-aarch64 cloud-image-utils wget qemu-utils \
    fio sysfsutils pciutils nvme-cli && \
    rm -rf /var/lib/apt/lists/*

# Download cloud images for both x86 and arm64 during build to save runtime execution time
WORKDIR /images
RUN wget https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img -O ubuntu-amd64.img && \
    wget https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-arm64.img -O ubuntu-arm64.img

# Setup workspace
WORKDIR /workspace

# Copy benchmark tools and their shared libraries directly into the 9p mount 
# This completely bypasses the need for the VM to run 'apt-get' which crawls under TCG software emulation!
RUN mkdir -p /workspace/bin /workspace/lib && \
    cp /usr/bin/fio /workspace/bin/ && \
    cp /usr/sbin/nvme /workspace/bin/ && \
    ldd /usr/bin/fio /usr/sbin/nvme | grep "=> /" | awk '{print $3}' | sort -u | xargs -I '{}' cp '{}' /workspace/lib/

COPY entrypoint.sh /workspace/
COPY vm_benchmark.sh /workspace/
COPY mongodb_profile.fio /workspace/
COPY cachelib_profile.fio /workspace/

RUN chmod +x /workspace/*.sh

ENTRYPOINT ["/workspace/entrypoint.sh"]
