## --- SYSCALL DEVELOPMENT PART --- ##

dev:
	cp src/get_pid_info/kernelspace/get_pid_info.c linux-4.19.322/kernel/
	make -j"$$(nproc)" -C ./linux-4.19.322
	./dev_scripts/exec_qemu_with_kernel.sh

dev_mount_root_fs:
	./dev_scripts/mount_root_fs.sh

# note that root_fs must be mounted
dev_copy_get_pid_info_userspace_code_to_root_fs:
	sudo cp src/get_pid_info/userspace/* /mnt/kroot_fs/root

dev_copy_test_to_root_fs:
	sudo cp src/tests/* /mnt/kroot_fs/root

dev_copy_to_root_fs: dev_copy_get_pid_info_userspace_code_to_root_fs dev_copy_test_to_root_fs

# todo qemu dev loop
# - ajouter le script de creation d'un root_fs

# todo common
# - automatiser l'ajout d'un syscall dans 'arch/x86/entry/syscalls/syscall_64.tbl'
# - automatiser l'ajout de '+obj-y += get_pid_info.o' dans kernel/Makefile
# - automatiser l'ajout du code user et kernel space

## --- SYSCALL INSTALLATION IN A REAL DISTRO PART --- ##




