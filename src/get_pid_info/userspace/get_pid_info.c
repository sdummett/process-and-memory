#include "get_pid_info.h"

long get_pid_info (struct pid_info *pid_info, int pid)
{
	return syscall(__NR_get_pid_info, pid_info, pid);
}
