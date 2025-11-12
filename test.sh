#!/bin/bash

set -e

echo "setting up a test VM"

TESTDIR="$HOME/test/instantos"

if ! [ -d "$TESTDIR" ]; then
    mkdir -p "$TESTDIR"
fi

DISKIMG="$TESTDIR/vm-disk.qcow2"
if ! [ -f "$DISKIMG" ]; then
    echo "Creating disk image at $DISKIMG"
    qemu-img create -f qcow2 "$TESTDIR/vm-disk.qcow2" 32G
else
    echo "Disk image already exists at $DISKIMG"
fi

LIVEISO="$HOME/Documents/iso/archlinux-2025.11.01-x86_64.iso"


echo "starting VM..."


if ! [ -e /dev/kvm ] || ! [ -r /dev/kvm ] || ! [ -w /dev/kvm ]; then
    echo "Error: /dev/kvm is unavailable or lacks read/write permissions. Ensure KVM is enabled and accessible." >&2
    exit 1
fi


cd "$TESTDIR"
qemu-system-x86_64 \
  -enable-kvm \
  -m 4G \
  -cpu host \
  -smp 4 \
  -drive file="$DISKIMG",format=qcow2,if=virtio,cache=none,aio=native \
  -bios /usr/share/edk2-ovmf/x64/OVMF.fd \
  -cdrom "$LIVEISO" \
  -boot menu=on,order=dc \
  -vga virtio \
  -display gtk,gl=on \
  -nic user,model=virtio-net-pci


