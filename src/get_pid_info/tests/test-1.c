#define _GNU_SOURCE
#include "get_pid_info.h"   // pid_info_t, PROC_STATE_*, get_pid_info()
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <signal.h>
#include <time.h>

/* conversion état -> chaine lisible */
static const char *state_to_str(int state)
{
    switch (state) {
    case PROC_STATE_RUNNING:  return "RUNNING";
    case PROC_STATE_SLEEPING: return "SLEEPING";
    case PROC_STATE_ZOMBIE:   return "ZOMBIE";
    default:                  return "UNKNOWN";
    }
}

/* petit helper pour dormir N ms */
static void msleep(int ms)
{
    struct timespec ts;
    ts.tv_sec  = ms / 1000;
    ts.tv_nsec = (ms % 1000) * 1000000L;
    nanosleep(&ts, NULL);
}

/* affiche un pid_info_t obtenu via get_pid_info() */
static void print_pid_info(const char *label, pid_t pid)
{
    pid_info_t info;
    long ret;

    printf("\n=== %s (pid=%d) ===\n", label, pid);

    errno = 0;
    ret = get_pid_info(&info, pid);
    if (ret < 0) {
        int err = errno;
        printf("get_pid_info(%d) FAILED: ret=%ld errno=%d (%s)\n",
               pid, ret, err, strerror(err));
        return;
    }

    printf("get_pid_info(%d) returned %ld\n", pid, ret);

    if (info.pid != pid) {
        printf("  [WARN] info.pid (%d) != pid demandé (%d)\n",
               info.pid, pid);
    }

    printf("  pid        = %d\n", info.pid);
    printf("  parent_pid = %d\n", info.parent_pid);
    printf("  stack_ptr  = %p\n", info.stack_pointer);
    printf("  age        = %d\n", info.age);
    printf("  state      = %s (%d)\n",
           state_to_str(info.state), info.state);
    printf("  root       = %s\n", info.root_path);
    printf("  cwd        = %s\n", info.current_working_directory);
}

int main(int ac, char *argv[])
{
    (void)ac;

    printf("[+] get_pid_info test program: %s (pid=%d)\n",
           argv[0], getpid());

    /* (1) test de base sur le processus appelant */
    print_pid_info("SELF", getpid());

    /* (2) cas d'erreur : PID invalides */
    print_pid_info("INVALID PID (-1)", -1);
    print_pid_info("INVALID PID (999999)", 999999);

    /* (3) création de différents types de processus enfant */

    pid_t parent_pid = getpid();
    pid_t child_running  = -1;
    pid_t child_sleeping = -1;
    pid_t child_zombie   = -1;

    /* (3.1) enfant RUNNING: boucle CPU (busy loop) */
    child_running = fork();
    if (child_running < 0) {
        perror("fork(child_running)");
        exit(1);
    }
    if (child_running == 0) {
        /* enfant RUNNING : chdir pour tester cwd, puis boucle CPU */
        if (chdir("/tmp") != 0) {
            perror("child_running: chdir(/tmp)");
        }
        printf("[child_running] pid=%d parent=%d, busy looping in /tmp\n",
               getpid(), getppid());

        volatile unsigned long x = 0;
        while (1) {
            x++;   /* boucle CPU => état RUNNING */
        }
        _exit(0);
    }

    /* (3.2) enfant SLEEPING: sleep(30) */
    child_sleeping = fork();
    if (child_sleeping < 0) {
        perror("fork(child_sleeping)");
        exit(1);
    }
    if (child_sleeping == 0) {
        printf("[child_sleeping] pid=%d parent=%d, sleeping...\n",
               getpid(), getppid());
        sleep(30);
        _exit(0);
    }

    /* (3.3) enfant ZOMBIE: exit immédiat, parent attend un peu avant wait() */
    child_zombie = fork();
    if (child_zombie < 0) {
        perror("fork(child_zombie)");
        exit(1);
    }
    if (child_zombie == 0) {
        printf("[child_zombie] pid=%d parent=%d, exiting now\n",
               getpid(), getppid());
        _exit(0);
    }

    /* laisser le temps aux enfants de changer d'état */
    msleep(500);  /* 0.5 s */

    printf("\n[+] Parent (pid=%d) testing children...\n", parent_pid);

    /* (4) interroger les différents PIDs */

    /* SELF à nouveau (voir si age/state changent) */
    print_pid_info("SELF (again)", parent_pid);

    /* enfant RUNNING (boucle CPU) */
    print_pid_info("child_running", child_running);

    /* enfant SLEEPING */
    print_pid_info("child_sleeping", child_sleeping);

    /* enfant ZOMBIE : on attend un peu pour être sûr qu'il soit zombie */
    msleep(500);
    print_pid_info("child_zombie (should be ZOMBIE)", child_zombie);

    /* (5) tuer l'enfant RUNNING avant de reap tout le monde */
    printf("\n[+] Killing child_running (pid=%d)\n", child_running);
    if (kill(child_running, SIGTERM) != 0) {
        perror("kill(child_running)");
    }
    msleep(200);  /* petit délai pour qu'il ait le temps de mourir */

    /* (6) nettoyage: wait sur les enfants (sinon on laisse des zombies) */
    printf("\n[+] Reaping children...\n");
    int status;
    pid_t w;
    int remaining = 3;
    while (remaining > 0) {
        w = waitpid(-1, &status, 0);
        if (w < 0) {
            perror("waitpid");
            break;
        }
        printf("  [waitpid] reaped pid=%d\n", w);
        remaining--;
        if (WIFEXITED(status)) {
            printf("    exit status = %d\n", WEXITSTATUS(status));
        } else if (WIFSIGNALED(status)) {
            printf("    killed by signal %d\n", WTERMSIG(status));
        }
    }

    printf("\n[+] Done.\n");
    return 0;
}
