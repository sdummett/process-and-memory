# process-and-memory: A Custom Linux Syscall (get_pid_info)

> Educational project exploring Linux kernel internals by adding a custom syscall, `get_pid_info`, to a patched Linux 4.19.322 kernel. It demonstrates process/task introspection (task_struct, PID namespaces, RCU-protected filesystem state) and the full workflow of patching, building, and testing a custom kernel with QEMU.

## Overview

`get_pid_info` is a new syscall (number 548) added directly to the Linux 4.19.322 kernel source tree. Given a PID, it returns kernel-side information about the corresponding process: PID, parent PID, uptime, scheduling state, kernel stack pointer, root directory, and current working directory.

This repository provides everything needed to reproduce the whole pipeline:

- the kernel patch itself (`src/get_pid_info/kernel/get_pid_info.c`)
- a `Makefile` that downloads the kernel source, applies the patch, builds the kernel, and either installs it on the host or boots it in QEMU with a minimal BusyBox rootfs
- user-space test programs that call the syscall and print the result

## What the syscall returns

```c
typedef struct pid_info {
    int             pid;
    void           *stack_pointer;
    int             age;                          // seconds since fork/exec
    int             parent_pid;
    process_state_e state;                        // RUNNING / SLEEPING / ZOMBIE
    char            root_path[PROCINFO_PATH_MAX];
    char            current_working_directory[PROCINFO_PATH_MAX];
} pid_info_t;
```

Retrieving this data touches several kernel subsystems: PID lookup (`find_vpid`, `get_pid_task`), scheduling state, the monotonic clock, and RCU-protected access to a process's `fs_struct` to resolve its root and working directory via the VFS. The full breakdown of every kernel structure and helper function involved is documented in [Kernel Internals Reference](#kernel-internals-reference) below.

## Requirements

- A Linux x86_64 environment with standard build tools: `gcc`, `make`, `wget`, `tar`
- `qemu-system-x86_64` to run the custom kernel/VM
- `sudo` rights, since several targets:
  - install a kernel into `/usr/src` and `/boot`
  - update `initramfs` and `grub`
  - manage files under `/lib/modules`

## Quick start

```bash
make dev
```

Downloads and patches the kernel (if needed), builds it, creates a BusyBox rootfs, injects the test binaries, and boots everything in QEMU. This is the recommended entry point: it never touches the host's installed kernel.

Once inside the VM:

```bash
./pidinfo 1
```

## Make targets

| Target | Description |
|--------|-------------|
| `all` / (default) | Downloads, patches, builds, and **installs** the kernel on the host (`/boot`, `/lib/modules`, `initramfs`, `grub`). Reboot and select kernel 4.19.322 to use it. |
| `dev` | Builds the patched kernel and boots it in QEMU with a BusyBox rootfs. Does not touch the host system. |
| `busybox` | Boots an already-built kernel + BusyBox rootfs in QEMU, without rebuilding. |
| `test-1-in-busybox` | Builds the `test-1` binary and injects it into the BusyBox rootfs. |
| `pidinfo-in-busybox` | Builds the `pidinfo` binary and injects it into the BusyBox rootfs. |
| `vm-install` | Creates a Debian VM disk image (`disks/debian.img`) via `scripts/vm.sh`. |
| `vm-launch` | Boots the previously created Debian VM. |
| `remove-linux` | Removes kernel 4.19.322 from the host and updates `initramfs`/`grub`, unless it is the kernel currently in use. |
| `clean` | Light cleanup of build artifacts. |
| `fclean` | Full cleanup: also removes the rootfs image and the downloaded kernel archive. |

## Typical workflows

- **Develop and test the syscall in an isolated VM (recommended):**
  ```bash
  make dev
  ```
- **Re-launch an already built VM without recompiling:**
  ```bash
  make busybox
  ```
- **Install the patched kernel directly on the host machine:**
  ```bash
  make
  ```
  Then select kernel `4.19.322` from the boot menu.
- **Use a fuller Debian VM instead of the minimal BusyBox rootfs:**
  ```bash
  make vm-install
  make vm-launch
  ```
- **Uninstall the patched kernel from the host:**
  ```bash
  make remove-linux
  ```
- **Clean generated files:**
  ```bash
  make clean    # light
  make fclean   # also removes the rootfs image and the kernel archive
  ```

## Disclaimer

This project patches and boots a custom Linux kernel for learning purposes only. Host-installation targets modify system boot configuration (`/boot`, `grub`, `initramfs`); run them in a disposable environment or VM unless you understand the consequences of a bad kernel installation.

---

## Kernel Internals Reference

Reference notes on the kernel structures, functions, and macros used to implement `get_pid_info`.

### 1. Kernel structures

#### 1.1 `struct task_struct`

- Defined in `<linux/sched.h>`.
- Represents a process or a thread in the kernel.
- Notably holds:
  - process identifiers (PID, TGID, etc.), accessible via helpers such as `task_pid_nr()`
  - the parent's ID via `task_ppid_nr()`
  - scheduling state (running, sleeping, zombie, etc.)
  - timing information (`start_time`, etc.)
  - a pointer to its `fs_struct` (`task->fs`)
  - the kernel stack address (`task->stack`)
  - scheduling, cgroup, and other subsystem structures

The code obtains a `struct task_struct *task` via `get_pid_task()`.

#### 1.2 `struct pid`

- Defined in `<linux/pid.h>`.
- Represents a process identifier in the kernel, with reference counting.
- Richer than a plain `int`: handles multiple PID namespaces and PID types (thread PID, group PID, etc.).
- Obtained with `find_vpid(pid)`, then the associated `task_struct` is retrieved via `get_pid_task()`.

#### 1.3 `struct fs_struct`

- Defined in `<linux/fs_struct.h>`.
- Represents a process's filesystem state:
  - current directory (`pwd`)
  - root directory (`root`), which can differ from `/` after a `chroot`
  - `umask`
  - references to the corresponding paths
- Accessible via `task->fs`.
- Some kernel threads have no `fs_struct`, hence the `if (!fs)` check in the code.

#### 1.4 `struct path`

- Defined in `<linux/path.h>`.
- Represents a path in the VFS (Virtual File System):
  - a `struct vfsmount *mnt` (mount point)
  - a `struct dentry *dentry` (dcache entry)
- Used with `get_fs_root()` and `get_fs_pwd()` to capture a process's root and current directory respectively.

### 2. Time and clock

#### 2.1 `ktime_get_ns()`

- Returns the current MONOTONIC clock time in nanoseconds (`u64`).
- The monotonic clock never goes backward; it is relative to system boot, with possible monotonic adjustments.
- Used here to compute the process's age.

#### 2.2 `task->start_time`

- Field of `struct task_struct`.
- Timestamp of process creation (fork/exec), in nanoseconds.
- Combined with `ktime_get_ns()`, gives the process's lifetime.

#### 2.3 `NSEC_PER_SEC`

- Macro defining the number of nanoseconds in a second (`1000000000`).
- Used to convert a nanosecond interval into whole seconds.

### 3. PID, tasks, and states

#### 3.1 `task_state_to_char(struct task_struct *task)`

- Helper defined in `<linux/sched.h>`.
- Converts a process's internal state (`task->state`, `task->exit_state`, etc.) into a character:
  - `'R'`: running
  - `'S'`: sleeping
  - `'D'`: uninterruptible sleep
  - `'T'`: stopped/traced
  - `'Z'`: zombie
  - etc.
- The code maps this character to the user-facing `enum process_state_e` (`PROC_STATE_RUNNING`, `PROC_STATE_SLEEPING`, `PROC_STATE_ZOMBIE`).

#### 3.2 `task_pid_nr(struct task_struct *task)`

- Returns a task's PID (`int`) in the visible PID namespace.
- Avoids handling `struct pid` directly.
- Used here to fill `kpid_info.pid`.

#### 3.3 `task_ppid_nr(struct task_struct *task)`

- Same idea as `task_pid_nr()`, but returns the parent's ID (PPID).
- Used to fill `kpid_info.parent_pid`.

#### 3.4 `find_vpid(int nr)`

- Defined in `<linux/pid.h>`.
- Looks up a `struct pid *` for number `nr` in the global PID namespace.
- Increments the refcount on the found `pid` object.
- Returns `NULL` if no process has this PID.

#### 3.5 `get_pid_task(struct pid *pid, enum pid_type type)`

- Also in `<linux/pid.h>`.
- From a `struct pid *` and a type (`PIDTYPE_PID`, `PIDTYPE_TGID`, etc.), returns the associated `struct task_struct *`.
- Increments the task's refcount (like `get_task_struct()`).
- Returns `NULL` if no task matches.

#### 3.6 `PIDTYPE_PID`

- PID type designating an individual process or thread.
- Passed to `get_pid_task()` to get the task associated with this "classic" PID.

#### 3.7 `put_task_struct(struct task_struct *task)`

- Reference-counting function for `task_struct`.
- Decrements the refcount on the task obtained earlier (here, via `get_pid_task()`).
- Once the refcount reaches zero, the structure can be freed.

### 4. RCU and synchronization

#### 4.1 `rcu_read_lock()` / `rcu_read_unlock()`

- RCU (Read-Copy-Update) primitives protecting reads of shared data.
- `task->fs` is RCU-protected; it must be accessed under `rcu_read_lock()`.
- Guarantees the read value will not be freed while the RCU critical section is open.

### 5. Filesystem-related functions

#### 5.1 `get_fs_root(struct fs_struct *fs, struct path *root)`

- Defined in `<linux/fs_struct.h>`.
- Retrieves the process's root directory (possibly different from `/` because of `chroot`).
- Increments references on the resulting `struct path` and its underlying objects.

#### 5.2 `get_fs_pwd(struct fs_struct *fs, struct path *pwd)`

- Also in `<linux/fs_struct.h>`.
- Retrieves the process's current working directory.
- Takes a reference on the returned `struct path`.

#### 5.3 `d_path(const struct path *path, char *buf, int buflen)`

- VFS function converting a `struct path` into a readable absolute path.
- Returns a pointer into `buf`, or an error pointer (encoded via `ERR_PTR()`).
- Used to fill the root and cwd paths in the user-facing struct.

#### 5.4 `path_put(struct path *path)`

- Releases a reference on a `struct path` obtained via `get_fs_root()` or `get_fs_pwd()`.
- Decrements refcounts on the associated dentry and vfsmount.

#### 5.5 `PATH_MAX`

- Constant defining the maximum path length in the kernel.
- Used to allocate the temporary buffer passed to `d_path()`.

### 6. Kernel memory allocation

#### 6.1 `kmalloc(size_t size, gfp_t flags)`

- Kernel-space memory allocation function.
- `GFP_KERNEL`: standard allocation, allowed to sleep (process context).
- Returns a valid pointer, or `NULL` on failure.

#### 6.2 `kfree(const void *objp)`

- Frees memory previously allocated with `kmalloc` or equivalent.

#### 6.3 `GFP_KERNEL`

- Flag passed to `kmalloc` indicating a "normal" kernel-side allocation context (may sleep / trigger reclaim).

### 7. User/kernel space access

#### 7.1 `copy_to_user(void __user *to, const void *from, unsigned long n)`

- Defined in `<linux/uaccess.h>`.
- Copies `n` bytes from kernel space (`from`) to user space (`to`).
- Validates the user address and handles page faults.
- Returns the number of bytes **not** copied (0 on success).

#### 7.2 `__user` annotation

- Used in `struct pid_info __user *upid_info`.
- Marks a pointer as pointing to user space.
- Helps static analysis and security-checking tools catch misuse.

### 8. Syscall infrastructure and logging

#### 8.1 `SYSCALL_DEFINE2`

- Macro defined in `<linux/syscalls.h>` to declare a syscall taking two arguments.
- Example:

```c
SYSCALL_DEFINE2(get_pid_info,
                struct pid_info __user *, upid_info,
                int, pid)
```

- Generates the function with the correct calling convention and wires it into the syscall table (per architecture and kernel configuration).

#### 8.2 `pr_info(...)` and `pr_err(...)`

- Kernel logging macros:
  - `pr_info`: informational messages
  - `pr_err`: error messages
- Both build on `printk` internally.
- Messages are visible via `dmesg` or the system journal.

#### 8.3 Error codes: `-EINVAL`, `-ESRCH`, `-EFAULT`

- Standard kernel error values (defined in `<linux/errno.h>`), returned by the syscall:
  - `-EINVAL`: invalid argument (e.g. `upid_info == NULL`)
  - `-ESRCH`: process not found (`find_vpid` or `get_pid_task` failed)
  - `-EFAULT`: invalid or inaccessible user address (`copy_to_user` failed)

### 9. String and memory utility functions

#### 9.1 `memset(void *s, int c, size_t n)`

- Sets a memory region to value `c` over `n` bytes.
- Used to zero out `kpid_info` before filling it.

#### 9.2 `strlcpy(char *dst, const char *src, size_t size)`

- Copies a string from `src` to `dst` with a size limit, guaranteeing NUL termination when `size > 0`.
- Safer than `strcpy`: avoids buffer overflows through controlled truncation.

#### 9.3 `IS_ERR(ptr)`

- Macro testing whether a pointer encodes an error.
- Some functions (like `d_path`) return either a valid pointer or an error pointer created with `ERR_PTR(-errno)`.
- `IS_ERR(p)` distinguishes between the two cases.

### 10. The `task->stack` field

- Field of `struct task_struct` pointing to the thread/process's kernel stack.
- Used here to fill `kpid_info.stack_pointer`.
- A kernel-space address, useful only for debugging/diagnostics, not directly usable from user space.
