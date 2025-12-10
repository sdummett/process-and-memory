#ifndef GET_PID_INFO_H
#define GET_PID_INFO_H

#define _GNU_SOURCE
#include <sys/syscall.h>
#include <unistd.h>
#include <stdio.h>
#include <errno.h>

#ifndef __NR_get_pid_info
#define __NR_get_pid_info 548
#endif

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

long get_pid_info (struct pid_info *pid_info, int pid)
{
	return syscall(__NR_get_pid_info, pid_info, pid);
}

#endif // GET_PID_INFO_H
