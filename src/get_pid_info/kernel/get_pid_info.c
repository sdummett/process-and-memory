#include <linux/syscalls.h>
#include <linux/pid.h>
#include <linux/sched.h>
#include <linux/uaccess.h>
#include <linux/string.h>
#include <linux/fs_struct.h>  // get_fs_root, get_fs_pwd, struct fs_struct
#include <linux/slab.h>   // kmalloc, kfree

#define PROCINFO_PATH_MAX 256

typedef enum {
	PROC_STATE_RUNNING = 0,
	PROC_STATE_SLEEPING = 1,
	PROC_STATE_ZOMBIE  = 2,
} process_state_e;

typedef struct pid_info {
	int             pid;
	void           *stack_pointer;
	int             age;
	int             parent_pid;
	process_state_e state;
	char            root_path[PROCINFO_PATH_MAX];
	char            current_working_directory[PROCINFO_PATH_MAX];
} pid_info_t;

static int get_task_age_sec(struct task_struct *task)
{
	u64 now_ns  = ktime_get_ns();        // horloge MONOTONIC = temps depuis boot + monotonic adj.
	u64 start_ns = task->start_time;     // timestamp exact du fork/exec
	u64 age_ns;

	if (now_ns <= start_ns)
		return 0;

	age_ns = now_ns - start_ns;

	return (int)(age_ns / NSEC_PER_SEC);
}

static process_state_e get_proc_state(struct task_struct *task)
{
	char c = task_state_to_char(task);

	switch (c) {
	case 'R':
		return PROC_STATE_RUNNING;
	case 'Z':
		return PROC_STATE_ZOMBIE;
	default:
		return PROC_STATE_SLEEPING;
	}
}

static void fill_paths_for_task(struct task_struct *task, pid_info_t *kpid_info)
{
	struct fs_struct *fs;
	struct path root, pwd;
	char *buf;
	char *p;

	kpid_info->root_path[0] = '\0';
	kpid_info->current_working_directory[0] = '\0';

	// certains threads noyau n'ont pas de fs_struct
	rcu_read_lock();
	fs = task->fs;
	if (!fs) {
		rcu_read_unlock();
		return;
	}

	// ces helpers prennent les refs nécessaires sur root/pwd
	get_fs_root(fs, &root);
	get_fs_pwd(fs, &pwd);
	rcu_read_unlock();

	buf = kmalloc(PATH_MAX, GFP_KERNEL);
	if (!buf) {
		// pas de mémoire -> on rend les refs et on laisse les strings vides
		path_put(&root);
		path_put(&pwd);
		return;
	}

	// root path
	p = d_path(&root, buf, PATH_MAX);
	if (!IS_ERR(p))
		strlcpy(kpid_info->root_path, p, sizeof(kpid_info->root_path));

	// cwd
	p = d_path(&pwd, buf, PATH_MAX);
	if (!IS_ERR(p))
		strlcpy(kpid_info->current_working_directory,
			p, sizeof(kpid_info->current_working_directory));

	kfree(buf);
	path_put(&root);  // rendu de la ref
	path_put(&pwd);
}

SYSCALL_DEFINE2(get_pid_info,
				struct pid_info __user *, upid_info,
				int, pid)
{
	struct pid_info   kpid_info;
	struct task_struct *task;
	struct pid         *pid_struct;
	int                 ret = 0;

	pr_info("get_pid_info(): called successfully\n");

	if (!upid_info) {
		pr_err("get_pid_info(): struct pid_info * is null\n");
		return -EINVAL;
	}

	pr_info("get_pid_info(): requested pid = %d\n", pid);

	pid_struct = find_vpid(pid);
	if (!pid_struct)
		return -ESRCH;

	task = get_pid_task(pid_struct, PIDTYPE_PID);
	if (!task)
		return -ESRCH;

	// a partir d'ici task est valide (refcount +1)

	memset(&kpid_info, 0, sizeof(kpid_info));

	kpid_info.pid            = task_pid_nr (task);
	kpid_info.parent_pid     = task_ppid_nr (task);
	kpid_info.stack_pointer  = task->stack;          // ou autre
	kpid_info.age            = get_task_age_sec (task);
	kpid_info.state          = get_proc_state (task);
	fill_paths_for_task (task, &kpid_info); // kpid_info.root_path & kpid_info.current_working_directory

	if (copy_to_user(upid_info, &kpid_info, sizeof(kpid_info))) {
		pr_err("get_pid_info(): copy_to_user() failed\n");
		ret = -EFAULT;
		goto out_put_task;
	}

	ret = 0;   // ou autre valeur de retour

out_put_task:
	put_task_struct(task);
	return ret;
}
