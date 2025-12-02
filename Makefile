# >> LINUX SYSCALLS << #

# DEVELOPMENT (using qemu to test the kernel with a minimal root filesystem)

LINUX_TREE				:= ./linux-4.19.322
ROOT_FS					:= ./disks/root_fs-ext4.img
LINUX_KERNEL_IMAGE		:= $(LINUX_TREE)/arch/x86/boot/bzImage
JOBS					:= $(shell echo $$(( $$(nproc) - 1 )))
KERNEL_CONFIG_NEED_YES	:= .kernel_config_need_yes

dev: linux
	@echo ">>> DEV <<<"
	sudo ./scripts/dev/create_root_fs.sh $(ROOT_FS)
	./scripts/dev/execute_kernel_plus_rootfs_with_qemu.sh $(LINUX_KERNEL_IMAGE) $(ROOT_FS)

# Setup du fichier de config
# Partiel car a la compilation on nous promptera afin d'editer .config
# Ca aura ete preferable d'avoir fini la configuration de .config ici
setup_kernel:
	echo ">>> SETUP KERNEL <<<"
	make -C $(LINUX_TREE) defconfig
	echo "CONFIG_VIRTIO_PCI=y" >> $(LINUX_TREE)/.config
	touch $(KERNEL_CONFIG_NEED_YES)

# Compilation du kernel
linux:
	@if [ -f "$(KERNEL_CONFIG_NEED_YES)" ]; then \
		echo "$(KERNEL_CONFIG_NEED_YES) existe, on pipe des 'y' dans la config kernel"; \
		yes | $(MAKE) -C $(LINUX_TREE) -j$(JOBS); \
		rm -f "$(KERNEL_CONFIG_NEED_YES)"; \
	else \
		echo "$(KERNEL_CONFIG_NEED_YES) n'existe pas, compilation normale du kernel"; \
		$(MAKE) -C $(LINUX_TREE) -j$(JOBS); \
	fi

all: setup_kernel dev

fclean:
	make -C $(LINUX_TREE) mrproper
	rm -f $(ROOT_FS)
	rm -f $(KERNEL_CONFIG_NEED_YES)

# ---------------------------------------------------------------------------- #
# CURRENT_SYSTEM (using the current system to install the kernel (reboot required))

# ---------------------------------------------------------------------------- #
# FOREIGN_SYSTEM (using a system in a disk to install the kernel and test this system in a vm)

# ---------------------------------------------------------------------------- #

## --- SYSCALL DEVELOPMENT PART --- ##

# dev:
# 	cp src/get_pid_info/kernelspace/get_pid_info.c linux-4.19.322/kernel/
# 	make -j"$$(nproc)" -C ./linux-4.19.322
# 	./dev_scripts/exec_qemu_with_kernel.sh

# dev_mount_root_fs:
# 	./dev_scripts/mount_root_fs.sh

# # note that root_fs must be mounted
# dev_copy_get_pid_info_userspace_code_to_root_fs:
# 	sudo cp src/get_pid_info/userspace/* /mnt/kroot_fs/root

# dev_copy_test_to_root_fs:
# 	sudo cp src/tests/* /mnt/kroot_fs/root

# dev_copy_to_root_fs: dev_copy_get_pid_info_userspace_code_to_root_fs dev_copy_test_to_root_fs

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ #

# todo qemu dev loop
# - ajouter le script de creation d'un root_fs

# todo common
# - automatiser l'ajout d'un syscall dans 'arch/x86/entry/syscalls/syscall_64.tbl'
# - automatiser l'ajout de '+obj-y += get_pid_info.o' dans kernel/Makefile
# - automatiser l'ajout du code user et kernel space

## --- SYSCALL INSTALLATION IN A REAL DISTRO PART --- ##




