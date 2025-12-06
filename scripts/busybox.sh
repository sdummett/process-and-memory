#!/bin/bash

## NOTE: busybox doit etre installer sur la machine hote

# - arrete le script des qu’une commande echoue (-e)
# - interdis l’usage de variables non définies (-u)
# - fais échouer un pipeline si une commande au milieu se plante (pipefail)
set -e #x

ROOTFS_IMG=$2
ROOTFS_DIR=$ROOTFS_IMG.rootfsdir
MOUNTPOINT=/mnt/busy_rootfs

if [[ -z "$ROOTFS_IMG" ]]; then
	echo "$0: usage : $0 [--install | --reinstall] <ROOTFS_IMG>"
	echo "$0: ROOTFS_IMG est le chemin ou l'image se trouvera"
	exit 1
fi

function install
{
	if [ -f $ROOTFS_IMG ]; then
		echo "$0: $ROOTFS_IMG existe deja."
		exit 0
	fi
	### (1) preparer l'aborescence de base

	sudo rm -rf "$ROOTFS_DIR"
	sudo mkdir "$ROOTFS_DIR"

	sudo mkdir -p "$ROOTFS_DIR"/{bin,sbin,etc,proc,sys,dev,dev/pts,tmp,root}
	sudo mkdir -p "$ROOTFS_DIR"/usr/{bin,sbin}
	sudo chmod 1777 "$ROOTFS_DIR/tmp"   # /tmp
	if ! BUSYBOX_BIN=$(command -v busybox 2>/dev/null); then
		echo "$0: Erreur : busybox n'est pas installe ou introuvable dans le PATH." >&2
		exit 1
	fi

	echo "$0: BusyBox = $BUSYBOX_BIN"

	# mettre busybox dans /bin
	sudo cp "$BUSYBOX_BIN" "$ROOTFS_DIR/bin/busybox"

	# copier les libs necessaires si busybox est dynamique
	for lib in $(ldd "$BUSYBOX_BIN" | awk '{if (substr($3,1,1)=="/") print $3}'); do
		sudo cp --parents "$lib" "$ROOTFS_DIR"
	done

	### (3) creer quelques symlinks importants (sh, ls, etc.)

	for app in sh ash ls cat mount umount dmesg echo ps top uname \
			mkdir rmdir mv cp rm vi sleep kill ping; do
		sudo ln -sf /bin/busybox "$ROOTFS_DIR/bin/$app"
	done

	### (4) /dev minimal (au cas ou devtmpfs ne monte pas tout seul)

	sudo mknod -m 600 "$ROOTFS_DIR/dev/console" c 5 1 || true
	sudo mknod -m 666 "$ROOTFS_DIR/dev/null"    c 1 3 || true

	### (5) script /init ultra simple

	cat << 'EOF' | sudo tee "$ROOTFS_DIR/init" >/dev/null
#!/bin/sh

echo "[init] Booting minimal BusyBox rootfs"

# monter les pseudo-fs
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev 2>/dev/null || echo "[init] devtmpfs mount failed"

# s'assurer que /dev/console existe
[ -c /dev/console ] || mknod -m 600 /dev/console c 5 1

echo "[init] Spawning shell on /dev/console"
exec /bin/sh </dev/console >/dev/console 2>&1
EOF

	sudo chmod +x "$ROOTFS_DIR/init"

	echo "$0: [+] Rootfs BusyBox construit dans $ROOTFS_DIR"

	### 6) construire l'image ext4

	# taille du rootfs en Mo
	SIZE_MB=$(sudo du -s -BM "$ROOTFS_DIR" | cut -f1 | tr -d M)
	ROOTFS_IMG_MB=$((SIZE_MB + 64))   # marge de 64 Mo

	echo "$0: [+] Taille rootfs: ${SIZE_MB}M, image: ${ROOTFS_IMG_MB}M"

	sudo rm -f "$ROOTFS_IMG"
	sudo dd if=/dev/zero of="$ROOTFS_IMG" bs=1M count="$ROOTFS_IMG_MB"
	sudo mkfs.ext4 "$ROOTFS_IMG"

	# copier le rootfs dans l'image
	sudo mkdir -p $MOUNTPOINT
	sudo mount -o loop "$ROOTFS_IMG" $MOUNTPOINT

	sudo rsync -aHAX --numeric-ids "$ROOTFS_DIR"/ $MOUNTPOINT

	sudo umount $MOUNTPOINT
	sudo rm -r "$MOUNTPOINT"
	sudo rm -r "$ROOTFS_DIR"

	sudo chown $USER:$USER "$ROOTFS_IMG"

	echo "$0: [+] Image rootfs prête: $ROOTFS_IMG"
	exit 0
}

function reinstall
{
	echo "$0: [+] Re-installation de busybox"

	sudo rm -rf "$MOUNTPOINT"
	sudo rm -rf "$ROOTFS_DIR"
	sudo rm -rf "$ROOTFS_IMG"

	install
}

case "$1" in
	--install)
	install
	;;
	--reinstall)
	reinstall
	;;
	*)
	echo "Option inconnue : $1"
	usage
	;;
esac
