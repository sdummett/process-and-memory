# >> LINUX SYSCALLS << #


LINUX_ARCHIVE			:= linux-4.19.322.tar.xz
LINUX_DIR				:= linux-4.19.322
LINUX_CONFIG			:= linux-4.19.322/.config
LINUX_IMG				:= linux-4.19.322/arch/x86/boot/bzImage
DISKS_DIR				:= disks
ROOTFS_IMG				:= $(DISKS_DIR)/rootfs.ext4
JOBS					:= $(shell echo $$(( $$(nproc) - 1 )))
INCLUDE					:= src/get_pid_info/userspace/


.PHONY: all linux dev clean fclean install-get_pid_info


all: dev


linux: $(LINUX_ARCHIVE) $(LINUX_DIR) $(LINUX_CONFIG) $(LINUX_IMG)


# using qemu to test the kernel with a minimal root filesystem
dev: $(ROOTFS_IMG) linux install-get_pid_info
	@echo "[COMPILE] kernel"
	$(MAKE) -C $(LINUX_DIR) -j$(JOBS) CC="gcc -std=gnu11" HOSTCC="gcc -std=gnu11"
	@echo "[EXEC] qemu: kernel+rootfs"
	./scripts/kernel-exec.sh $(LINUX_IMG) $(ROOTFS_IMG)


$(LINUX_IMG):
	@echo "[COMPILE] linux"
	yes | $(MAKE) -C $(LINUX_DIR) -j$(JOBS) CC="gcc -std=gnu11" HOSTCC="gcc -std=gnu11"


# Setup du fichier de config
# Partiel car a la compilation on nous promptera afin d'editer .config
# Ca aura ete preferable d'avoir fini la configuration de .config ici
$(LINUX_CONFIG):
	@echo "[CONFIG] linux .config (defconfig)"
	make -C $(LINUX_DIR) defconfig
	echo "CONFIG_VIRTIO_PCI=y" >> $(LINUX_DIR)/.config


$(LINUX_ARCHIVE):
	@echo "[DOWNLOAD] $(LINUX_ARCHIVE)"
	wget -O $(LINUX_ARCHIVE) https://cdn.kernel.org/pub/linux/kernel/v4.x/$(LINUX_ARCHIVE)


## gcc + flex + bison needed, need to check it
# sudo dnf install openssl-devel openssl-devel-engine
## en gros il faut connaitre les paquets requis par la compilation du kernel
$(LINUX_DIR):
	@echo "[UNPACK] $(LINUX_ARCHIVE)"
	tar -xvf $(LINUX_ARCHIVE)


$(ROOTFS_IMG):
	@mkdir -p $(DISKS_DIR)
	@echo "[INSTALL] $(ROOTFS_IMG)"
	./scripts/busybox.sh --reinstall $(ROOTFS_IMG)


KERNEL_SYSCALL_DST	:= $(LINUX_DIR)/kernel/get_pid_info.c
LOCAL_SYSCALL_SRC	:= src/get_pid_info/kernelspace/get_pid_info.c

add-to-syscall-table:
	./scripts/kernel-add-syscall.sh $(LINUX_DIR) get_pid_info src/get_pid_info/userspace/get_pid_info.h $(LOCAL_SYSCALL_SRC)

install-get_pid_info: add-to-syscall-table $(KERNEL_SYSCALL_DST)

$(KERNEL_SYSCALL_DST): $(LOCAL_SYSCALL_SRC)
	@echo ">> Mise à jour de $(KERNEL_SYSCALL_DST) depuis $(LOCAL_SYSCALL_SRC)"
	cp $< $@

bin/get_pid_info/tests/dummy-test:
	mkdir -p bin/get_pid_info/tests/
	gcc -Wall -O2 -static -o bin/get_pid_info/tests/dummy-test src/get_pid_info/tests/dummy-test.c
	./scripts/busybox.sh --add disks/rootfs.ext4 bin/get_pid_info/tests/dummy-test


bin/get_pid_info/tests/test-1:
	mkdir -p bin/get_pid_info/tests/
	gcc -Wall -O2 -static -I$(INCLUDE) -o bin/get_pid_info/tests/test-1 src/get_pid_info/tests/test-1.c
	./scripts/busybox.sh --add disks/rootfs.ext4 bin/get_pid_info/tests/test-1


clean:
	@echo "[CLEAN]"
	$(MAKE) -C $(LINUX_DIR) mrproper || true # supprime .config arch/x86/boot/bzImage


fclean: clean
	@echo "[FCLEAN]"
	rm -f $(ROOTFS_IMG)
	rm -rf $(LINUX_DIR)
	rm -rf $(LINUX_ARCHIVE)


# todo common
# - automatiser l'ajout d'un syscall dans 'arch/x86/entry/syscalls/syscall_64.tbl'
# - automatiser l'ajout de '+obj-y += get_pid_info.o' dans kernel/Makefile
# - automatiser l'ajout du code user et kernel space
