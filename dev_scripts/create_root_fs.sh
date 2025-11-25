#!/bin/bash

# >> ROOTFS CREATTION PART <<<
# on cree un root filesystem (rootfs) (Debian minimal)

# 1. Creation de l'image (4 Go, on ajuste au besoin)
fallocate -l 4G root_filesystem
sudo mkfs.ext4 -F root_filesystem

# 2. On monte l’image
sudo mkdir -p /mnt/kkroot_filesystem
sudo mount -o loop root_filesystem /mnt/kkroot_filesystem

# On installe la Debian minimal dedans (on choisi une version qui supportera notre kernel linux 4.x.y , ex: bullseye).
sudo debootstrap --arch=amd64 bullseye /mnt/kkroot_filesystem http://deb.debian.org/debian

# 3. On demonte l'image
sudo umount /mnt/kkroot_filesystem

# Ici on tweak notre root_fs en faisant un chroot

# On monte le filesystem (root_fs doit etre a porte de main)
# sudo mkdir /mnt/kroot_fs
# sudo mount -o loop root_fs /mnt/kroot_fs
# sudo mount --bind /dev /mnt/kroot_fs/dev
# sudo mount --bind /dev/pts /mnt/kroot_fs/dev/pts
# sudo mount -t proc /proc /mnt/kroot_fs/proc
# sudo mount -t sysfs /sys /mnt/kroot_fs/sys
# sudo mount -t tmpfs tmpfs /mnt/kroot_fs/run

# sudo chroot /mnt/kroot_fs /bin/bash

# Et on chroot dedans
#sudo chroot /mnt/kroot_fs

# apt install vim gcc
