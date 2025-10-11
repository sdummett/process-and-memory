#!/bin/bash

qemu-system-x86_64 \
  -enable-kvm \
  -cpu host \
  -m 16G \
  -smp 16 \
  -hda debian.img \
  -cdrom  debian-10.13.0-amd64-netinst.iso \
  -boot d \
  -net nic -net user
