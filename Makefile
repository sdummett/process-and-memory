# >> LINUX SYSCALLS << #


LINUX_ARCHIVE			:= linux-4.19.322.tar.xz
# LINUX_DIR				:= linux-4.19.322
DISKS_DIR				:= disks
DEV_ROOTFS_IMG			:= $(DISKS_DIR)/rootfs.ext4
JOBS					:= $(shell echo $$(( $$(nproc) - 1 )))
INCLUDE					:= src/get_pid_info/include/
LOCAL_SYSCALL_SRC		:= src/get_pid_info/kernel/get_pid_info.c
LINUX_SYSTEM_SRC_PATH	:= /usr/src/linux-4.19.322


.PHONY: all re clean fclean add-get-pid-info-to-syscall-table add-get-pid-info-obj \
		build-linux-in-system test-1-in-busybox dev vm-install vm-launch busybox


all: build-linux-in-system


# on ajoute get_pid_info.c dans /usr/src/linux-4.19.322/kernel et sa table de syscall
add-get-pid-info-to-syscall-table:
	@echo "[INSTALL] ajout de get_pid_info.c dans /usr/src/linux-4.19.322"
	@echo "[INSTALL] update de ./src/get_pid_info/include/get_pid_info.h avec le sysnum correct"
	./scripts/kernel-add-syscall.sh /usr/src/linux-4.19.322 get_pid_info ./src/get_pid_info/include/get_pid_info.h $(LOCAL_SYSCALL_SRC)


# on ajoute "obj-y += get_pid_info.o" a kernel/Makefile
add-get-pid-info-obj:
	@echo "[CHECK] Ajout éventuel de get_pid_info.o dans kernel/Makefile"
	@if ! grep -q -E '^[[:space:]]*obj-y[[:space:]]*\+=[[:space:]]*get_pid_info\.o' "$(LINUX_SYSTEM_SRC_PATH)/kernel/Makefile"; then \
		echo "[PATCH] ajout de get_pid_info.o dans kernel/Makefile"; \
		echo "obj-y += get_pid_info.o" | sudo tee -a "$(LINUX_SYSTEM_SRC_PATH)/kernel/Makefile" >/dev/null; \
	else \
		echo "[SKIP] get_pid_info.o déjà présent dans kernel/Makefile"; \
	fi


# copie des sources linux vers /usr/src/linux-4.19.322
/usr/src/linux-4.19.322:
	@echo "[UNPACK] $(LINUX_ARCHIVE)"
	@if [ ! -f $(LINUX_ARCHIVE) ]; then \
		echo "[INFO] You should run 'make $(LINUX_ARCHIVE)' to download the Linux archive"; \
		exit 1; \
	else \
		tar -xvf $(LINUX_ARCHIVE) -C /tmp; \
		sudo mv /tmp/linux-4.19.322 /usr/src/; \
	fi


# installation du kernel dans /usr/src +
# ajout du syscall get_pid_info +
# build de linux +
# installation de l'image dans /boot +
# configuration de grub
build-linux-in-system: /usr/src/linux-4.19.322 add-get-pid-info-to-syscall-table add-get-pid-info-obj bin/get_pid_info/tests/test-1 bin/get_pid_info/tests/pidinfo
	@echo "[JOBS] $(JOBS)"
	@echo "[SETUP] linux kernel '.config' to defconfig"
	@$(MAKE) -C $(LINUX_SYSTEM_SRC_PATH) defconfig
	@echo "[PATCH] ajout de CONFIG_VIRTIO_PCI=y dans .config"
	@echo "CONFIG_VIRTIO_PCI=y" >> $(LINUX_SYSTEM_SRC_PATH)/.config
	@echo "[COMPILE] kernel (system tree: $(LINUX_SYSTEM_SRC_PATH))"
	@yes | $(MAKE) -C $(LINUX_SYSTEM_SRC_PATH) -j$(JOBS) CC="gcc -std=gnu11" HOSTCC="gcc -std=gnu11"
	@echo "Compiled kernel $(LINUX_SYSTEM_SRC_PATH)"
	@echo "[INSTALL] linux modules"
	@sudo $(MAKE) -C $(LINUX_SYSTEM_SRC_PATH) modules_install
	@echo "[INSTALL] linux"
	@sudo $(MAKE) -C $(LINUX_SYSTEM_SRC_PATH) install
	@echo "[INSTALL] update-initramfs"
	@sudo update-initramfs -c -k 4.19.322
	@echo "[INSTALL] update-grub"
	@sudo update-grub

$(DEV_ROOTFS_IMG):
	@mkdir -p $(DISKS_DIR)
	@echo "[INSTALL] $(DEV_ROOTFS_IMG)"
	./scripts/busybox.sh --reinstall $(DEV_ROOTFS_IMG)

# ajout du test de get_pid_info dans le rootfs
test-1-in-busybox: bin/get_pid_info/tests/test-1
	./scripts/busybox.sh --add disks/rootfs.ext4 bin/get_pid_info/tests/test-1

# ajout du test de get_pid_info dans le rootfs
pidinfo-in-busybox: bin/get_pid_info/tests/pidinfo
	./scripts/busybox.sh --add disks/rootfs.ext4 bin/get_pid_info/tests/pidinfo

# execution du kernel+rootfs grace a qemu
busybox:
	@echo "[EXEC] qemu: kernel+rootfs"
	./scripts/kernel-exec.sh /usr/src/linux-4.19.322/arch/x86/boot/bzImage $(DEV_ROOTFS_IMG)


# using qemu to test the kernel with a minimal root filesystem
dev: /usr/src/linux-4.19.322 $(DEV_ROOTFS_IMG) test-1-in-busybox pidinfo-in-busybox add-get-pid-info-to-syscall-table add-get-pid-info-obj
	@echo "[JOBS] $(JOBS)"
	@echo "[SETUP] linux kernel '.config' to defconfig"
	@$(MAKE) -C $(LINUX_SYSTEM_SRC_PATH) defconfig
	@echo "[PATCH] ajout de CONFIG_VIRTIO_PCI=y dans .config"
	@echo "CONFIG_VIRTIO_PCI=y" >> $(LINUX_SYSTEM_SRC_PATH)/.config
	@echo "[COMPILE] kernel (system tree: $(LINUX_SYSTEM_SRC_PATH))"
	@yes | $(MAKE) -C $(LINUX_SYSTEM_SRC_PATH) -j$(JOBS) CC="gcc -std=gnu11" HOSTCC="gcc -std=gnu11"
	@echo "Compiled kernel $(LINUX_SYSTEM_SRC_PATH)"
	@echo "[EXEC] qemu: kernel+rootfs"
	./scripts/kernel-exec.sh /usr/src/linux-4.19.322/arch/x86/boot/bzImage $(DEV_ROOTFS_IMG)


bin/get_pid_info/tests/dummy-test:
	mkdir -p bin/get_pid_info/tests/
	gcc -Wall -O2 -static -o bin/get_pid_info/tests/dummy-test src/get_pid_info/tests/dummy-test.c
	./scripts/busybox.sh --add disks/rootfs.ext4 bin/get_pid_info/tests/dummy-test

# compilation du test de get_pid_info ()
bin/get_pid_info/tests/test-1:
	mkdir -p bin/get_pid_info/tests/
	gcc -Wall -O2 -static -I$(INCLUDE) -o bin/get_pid_info/tests/test-1 src/get_pid_info/tests/test-1.c

# compilation de pidinfo programme affichant la structure delivre
# par le syscall `get_pid_info` d'un ou plusieurs pids
bin/get_pid_info/tests/pidinfo:
	mkdir -p bin/get_pid_info/tests/
	gcc -Wall -O2 -static -I$(INCLUDE) -o bin/get_pid_info/tests/pidinfo src/get_pid_info/tests/pidinfo.c

# telechargement de l'arborescence linux-4.19.322
$(LINUX_ARCHIVE):
	@echo "[DOWNLOAD] $(LINUX_ARCHIVE)"
	wget -O $(LINUX_ARCHIVE) https://cdn.kernel.org/pub/linux/kernel/v4.x/$(LINUX_ARCHIVE)


# Creation d'une vm debian
vm-install:
	./scripts/vm.sh --install ./disks/debian.img
# Lancement d'une vm debian
vm-launch:
	./scripts/vm.sh --launch ./disks/debian.img

LINUX_VER_TO_RM=4.19.322
remove-linux:
	@if ! uname -r | grep $(LINUX_VER_TO_RM) ; then \
		echo "[REMOVE] linux-$(LINUX_VER_TO_RM) from system and grub"; \
		sudo rm /boot/vmlinuz-$(LINUX_VER_TO_RM); \
		sudo rm /boot/initrd.img-$(LINUX_VER_TO_RM); \
		sudo rm /boot/System.map-$(LINUX_VER_TO_RM); \
		sudo rm /boot/config-$(LINUX_VER_TO_RM); \
		sudo rm -rf /lib/modules/$(LINUX_VER_TO_RM); \
		sudo update-initramfs -d -k $(LINUX_VER_TO_RM); \
		sudo update-grub; \
	else \
		echo "[SKIP] linux-$(LINUX_VER_RO_RM) est actuellement en cours d'utilisation"; \
	fi


clean:
	@echo "[CLEAN] ./bin/get_pid_info/tests/*"
	@rm -rf ./bin/get_pid_info/tests/*
	@echo "[MRPROPER] /usr/src/linux-4.19.322"
	@$(MAKE) -C /usr/src/linux-4.19.322 mrproper
# 	$(MAKE) -C $(LINUX_DIR) mrproper || true # supprime .config arch/x86/boot/bzImage


fclean: clean
	@echo "[FCLEAN] $(DEV_ROOTFS_IMG)"
	@rm -f $(DEV_ROOTFS_IMG)
	@echo "[FCLEAN] /usr/src/linux-4.19.322"
	@sudo rm -rf /usr/src/linux-4.19.322
# 	rm -rf $(LINUX_DIR)
	@echo "[FCLEAN] $(LINUX_ARCHIVE)"
	@rm -rf $(LINUX_ARCHIVE)
