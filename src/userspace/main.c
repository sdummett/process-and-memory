#include "get_pid_info.h"
#include <stdio.h>

int main ()
{
        pid_info_t pid_info;
        printf("get_pid_info returned %ld\n", get_pid_info(&pid_info, 1));

        printf ("pid_info.pid = %d\n", pid_info.pid);
        printf ("pid_info.parent_pid = %d\n", pid_info.parent_pid);
        printf ("pid_info.stack_pointer = 0x%lx\n", pid_info.stack_pointer);
        printf ("pid_info.age = %d\n", pid_info.age);
		char *pstate = "ZOMBIE";
		if (pid_info.state == PROC_STATE_RUNNING)
		{
			pstate = "RUNNING";
		}
		else if (pid_info.state == PROC_STATE_SLEEPING)
		{
			pstate = "SLEEPING";
		}
        printf ("pid_info.state = %s\n", pstate);
        printf ("pid_info.root_path = %s\n", pid_info.root_path);
        printf ("pid_info.current_working_directory = %s\n", pid_info.current_working_directory);
        return 0;
}
