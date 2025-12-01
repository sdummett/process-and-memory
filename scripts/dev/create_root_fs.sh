#!/bin/bash

# !!! NOTE !!! Il faut lancer ce script avec sudo !
# !!! NOTE !!! Le password de 'root' est $ROOT_PASSWORD (a chercher dans le script)

# Ce script cree un filesystem ext4 dans une image et
# installe un systeme de base dans celui-ci

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
ROOT_PASSWORD=root

function mount_root_fs
{
	echo "$0: MOUNTPOINT=$MOUNTPOINT"

	mkdir "$MOUNTPOINT"
	mount -o loop $ROOT_FS $MOUNTPOINT

	mkdir -p "$MOUNTPOINT/dev" \
	         "$MOUNTPOINT/dev/pts" \
	         "$MOUNTPOINT/proc" \
	         "$MOUNTPOINT/sys" \
	         "$MOUNTPOINT/run"

	mount --bind /dev $MOUNTPOINT/dev
	mount --bind /dev/pts $MOUNTPOINT/dev/pts
	mount -t proc /proc $MOUNTPOINT/proc
	mount -t sysfs /sys $MOUNTPOINT/sys
	mount -t tmpfs tmpfs $MOUNTPOINT/run

	# > DEBUG_START
	# lsblk
	# tree -L 1 $MOUNTPOINT
	# exit 42
	# > DEBUG_END
}

function umount_root_fs
{
	umount -R $MOUNTPOINT

	# umount $MOUNTPOINT/dev/pts
	# umount $MOUNTPOINT/dev
	# umount $MOUNTPOINT/run
	# umount $MOUNTPOINT/sys
	# umount $MOUNTPOINT/proc
	# umount $MOUNTPOINT

	rm -r $MOUNTPOINT
}

function create_root_fs
{
	echo "Trying to create '$ROOT_FS'"

	# creation de l'image (6 Go, a ajuster au besoin)
	fallocate -l 6G $ROOT_FS
	mkfs.ext4 -F $ROOT_FS

	# $SUDO_USER => le login de l’utilisateur original
	# $SUDO_UID  => son UID
	# $SUDO_GID  => son GID
	# echo "the original user ===> $SUDO_USER"
	chown $SUDO_USER:$SUDO_USER $ROOT_FS

	# on monte l’image
	mount_root_fs

	# on installe la Debian minimal dedans (on choisi une version qui supportera notre kernel linux-4.x.y).
	debootstrap --arch=amd64 bullseye $MOUNTPOINT http://deb.debian.org/debian
	sudo chroot $MOUNTPOINT /bin/bash -c "echo 'root:$ROOT_PASSWORD' | chpasswd"

	## note: if needed you can install vim et gcc by chrooting in the filesystem

	umount_root_fs
}

# >>> Main <<< #
if [[ ! "$ROOT_FS" = /* ]]; then
	echo "$0: The path to the root filesystem must be absolute"
	exit 1;
fi

# -z: test si la chaine est vide
if [[ -z "$ROOT_FS" ]]; then
	echo "$0: usage: $CMD <root_filesystem_path>"
	exit 1
fi

if [[ -f "$ROOT_FS" ]]; then
	echo "$0: $1 is already installed"
	exit 0
fi

create_root_fs

