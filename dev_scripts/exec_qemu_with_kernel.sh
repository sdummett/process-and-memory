#!/bin/bash

# 1. compilation du noyau au cas ou des changements on ete effectue
# make -j"$(nproc)"

# 2. lancement de QEMU avec ce noyau
qemu-system-x86_64 \
  -kernel ./linux-4.19.322/arch/x86/boot/bzImage \
  -append "root=/dev/vda rw console=ttyS0" \
  -drive file=disks/root_fs,if=virtio,format=raw \
  -m 1024 \
  -nographic

# lancement du noyau sans root filesystem
#qemu-system-x86_64 \
#    -kernel "$BUILD/arch/x86/boot/bzImage" \
#    -append "root=/dev/sda1 rw console=ttyS0" \
#    -hda ft_linux.img \
#    -nographic
