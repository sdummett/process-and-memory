#!/bin/bash

# todo verifier si les mountpoints sont deja monte
# todo il faut creer le /mnt/kroot_fs/* si ils sont non existants

sudo mount -o loop root_fs /mnt/kroot_fs
sudo mount --bind /dev /mnt/kroot_fs/dev
sudo mount --bind /dev/pts /mnt/kroot_fs/dev/pts
sudo mount -t proc /proc /mnt/kroot_fs/proc
sudo mount -t sysfs /sys /mnt/kroot_fs/sys
sudo mount -t tmpfs tmpfs /mnt/kroot_fs/run
