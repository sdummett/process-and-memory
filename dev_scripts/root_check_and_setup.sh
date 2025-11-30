#!/bin/bash

# 1. Si `ROOT_FS` existe on quitte
# 2. Creer `ROOT_FS`
# 3. Monter `ROOT_FS`
# 4. Installer le systeme de base
# 5. Installer des commandes supplementaires necessaires

# Afin de quitter le script des qu'une erreur se produit
set -e #x

# ROOT_FS must be an absolute path to root filesystem disk
CMD=$(basename $0)
ROOT_FS=$1
MOUNTPOINT=/mnt/$CMD-root_fs

function mount_root_fs
{
	echo "$0: MOUNTPOINT=$MOUNTPOINT"

	sudo mkdir "$MOUNTPOINT"
	sudo mount -o loop $ROOT_FS $MOUNTPOINT

	sudo mkdir -p "$MOUNTPOINT/dev" \
	             "$MOUNTPOINT/dev/pts" \
	             "$MOUNTPOINT/proc" \
	             "$MOUNTPOINT/sys" \
	             "$MOUNTPOINT/run"

	sudo mount --bind /dev $MOUNTPOINT/dev
	sudo mount --bind /dev/pts $MOUNTPOINT/dev/pts
	sudo mount -t proc /proc $MOUNTPOINT/proc
	sudo mount -t sysfs /sys $MOUNTPOINT/sys
	sudo mount -t tmpfs tmpfs $MOUNTPOINT/run

	# > DEBUG_START
	lsblk
	tree -L 1 $MOUNTPOINT
	# exit 42
	# > DEBUG_END
}

function umount_root_fs
{
	sudo umount $MOUNTPOINT/run
	sudo umount $MOUNTPOINT/sys
	sudo umount $MOUNTPOINT/proc
	sudo umount $MOUNTPOINT/dev/pts
	sudo umount $MOUNTPOINT/dev
	sudo umount $MOUNTPOINT

	sudo rm -r $MOUNTPOINT
}

function create_root_fs
{
	echo "Trying to create '$ROOT_FS'"

	# 1. Creation de l'image (6 Go, on ajuste au besoin)
	fallocate -l 6G $ROOT_FS
	sudo mkfs.ext4 -F $ROOT_FS

	# 2. On monte l’image
	mount_root_fs
	# sudo mount -o loop $ROOT_FS $MOUNTPOINT

	# On installe la Debian minimal dedans (on choisi une version qui supportera notre kernel linux 4.x.y , ex: bullseye).
	sudo debootstrap --arch=amd64 bullseye $MOUNTPOINT http://deb.debian.org/debian

	## TODO installer vim et gcc

	# umount_root_fs
}

# >>> Main <<< #
if [[ ! "$ROOT_FS" = /* ]]; then
	echo "$0: The path to the root filesystem must be absolute"
	exit 1;
fi

# TODO: what is '-z' ?
if [[ -z $ROOT_FS ]] then
	echo "$0: usage: $CMD <root_filesystem_path>"
	exit 1
fi

if [[ -f "$ROOT_FS" ]] then
	echo "$0: $1 is already installed"
	exit 0
fi

create_root_fs

