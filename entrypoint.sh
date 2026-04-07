#!/bin/bash
set -e

ARCH=$(uname -m)
echo "Docker Container Architecture: $ARCH"

if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
    QEMU=qemu-system-aarch64
    IMG_BASE=/images/ubuntu-arm64.img
    MACHINE="virt,gic-version=3"
    CPU="max"
    FIRMWARE="-bios /usr/share/qemu-efi-aarch64/QEMU_EFI.fd"
    CONSOLE="ttyAMA0"
else
    QEMU=qemu-system-x86_64
    IMG_BASE=/images/ubuntu-amd64.img
    MACHINE="q35"
    CPU="max"
    FIRMWARE=""
    CONSOLE="ttyS0"
fi

# Prepare a clean CoW image so multiple runs don't corrupt the base
mkdir -p /workspace/run
qemu-img create -f qcow2 -b "$IMG_BASE" -F qcow2 /workspace/run/vm.qcow2 10G

# Provision ZNS and FDP backing files
echo "Provisioning Emulated NVMe Backing Drives..."
qemu-img create -f raw /workspace/run/zns.img 2G
qemu-img create -f raw /workspace/run/fdp.img 2G

# Cloud-Init Config (user-data)
cat <<EOF > /workspace/run/user-data
#cloud-config
ssh_pwauth: true
chpasswd:
  list: |
    ubuntu:ubuntu
  expire: false
mounts:
  - [ "workspace", "/host", "9p", "trans=virtio,version=9p2000.L,msize=10485760", "0", "0" ]
runcmd:
  - echo "VM Booted. Executing Benchmark." > /dev/${CONSOLE}
  - "bash /host/vm_benchmark.sh | tee /host/results/vm_execution.log > /dev/${CONSOLE} 2>&1"
  - poweroff
EOF

cat <<EOF > /workspace/run/meta-data
instance-id: nvme-test-vm
local-hostname: nvme-test-vm
EOF

cloud-localds /workspace/run/seed.iso /workspace/run/user-data /workspace/run/meta-data

mkdir -p /workspace/results

echo "Starting QEMU VM Virtualization..."

# Attempt to use KVM if the host supports passed-through virtualization
ACCEL="tcg"
if [ -e /dev/kvm ]; then
    ACCEL="kvm"
    CPU="host"
    echo "KVM Hardware Acceleration Enabled."
else
    echo "Using Software Emulation (TCG). This is slower but inherently portable."
fi

# We mount /workspace as a 9p share so the VM can read the scripts and write back results
$QEMU -machine $MACHINE,accel=$ACCEL -cpu $CPU -m 2G -smp 2 \
    $FIRMWARE \
    -nographic \
    -netdev user,id=net0 \
    -device virtio-net-pci,netdev=net0 \
    -drive if=virtio,file=/workspace/run/vm.qcow2,format=qcow2 \
    -drive if=virtio,file=/workspace/run/seed.iso,format=raw \
    -fsdev local,security_model=none,id=fsdev0,path=/workspace \
    -device virtio-9p-pci,id=fs0,fsdev=fsdev0,mount_tag=workspace \
    -drive file=/workspace/run/zns.img,id=zns_drive,format=raw,if=none \
    -device nvme,id=nvme_zns,serial=123ZNS \
    -device nvme-ns,drive=zns_drive,bus=nvme_zns,nsid=1,zoned=on,zoned.zone_size=64M,zoned.zone_capacity=64M \
    -drive file=/workspace/run/fdp.img,id=fdp_drive,format=raw,if=none \
    -device nvme-subsys,id=nvme_subsys_fdp,nqn=subsys0,fdp=on,fdp.nruh=16,fdp.nrg=1,fdp.runs=96M \
    -device nvme,id=nvme_fdp,serial=123FDP,subsys=nvme_subsys_fdp \
    -device nvme-ns,drive=fdp_drive,bus=nvme_fdp,nsid=1

echo "QEMU Execution Completed. Writing out status."
chmod -R a+rw /workspace/results || true
