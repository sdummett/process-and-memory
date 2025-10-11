#!/bin/bash

qemu-system-x86_64 \
  -enable-kvm \
  -cpu host \
  -m 16G \
  -smp 16 \
  -hda debian.img \
  -net nic -net user,hostfwd=tcp::2222-:22
