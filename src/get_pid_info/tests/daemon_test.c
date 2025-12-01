// daemon_test.c
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <syslog.h>
#include <signal.h>

static void daemonize(void)
{
    pid_t pid;

    // 1er fork : détacher du terminal
    pid = fork();
    if (pid < 0)
        exit(EXIT_FAILURE);
    if (pid > 0)
        exit(EXIT_SUCCESS); // on quitte le parent

    // On est dans le premier enfant
    if (setsid() < 0)
        exit(EXIT_FAILURE);

    // Optionnel : ignorer SIGHUP
    signal(SIGHUP, SIG_IGN);

    // 2ème fork : éviter de reprendre un terminal
    pid = fork();
    if (pid < 0)
        exit(EXIT_FAILURE);
    if (pid > 0)
        exit(EXIT_SUCCESS); // quitter le 1er enfant

    // On est dans le vrai daemon
    umask(0);
    chdir("/");

    // Fermer stdin/stdout/stderr
    close(STDIN_FILENO);
    close(STDOUT_FILENO);
    close(STDERR_FILENO);

    // On ouvre syslog pour voir quelque chose
    openlog("daemon_test", LOG_PID, LOG_DAEMON);
}

static void child_loop(int id)
{
    // voici la boucle infinie de l'enfant
    while (1) {
        syslog(LOG_INFO, "Child %d alive, pid=%d", id, getpid());
        sleep(10);
    }
}

int main(void)
{
    pid_t c1, c2;

    daemonize();

    syslog(LOG_INFO, "Daemon started, pid=%d", getpid());

    // on cree le 1er enfant
    c1 = fork();
    if (c1 < 0) {
        syslog(LOG_ERR, "fork child1 failed");
        exit(EXIT_FAILURE);
    }
    if (c1 == 0) {
        // process 1
        child_loop(1);
    }

    // on cree le 2eme enfant
    c2 = fork();
    if (c2 < 0) {
        syslog(LOG_ERR, "fork child2 failed");
        exit(EXIT_FAILURE);
    }
    if (c2 == 0) {
        // process 2
        child_loop(2);
    }

    syslog(LOG_INFO, "Daemon parent running, children: %d, %d", c1, c2);

    // boucle infinie du parent
    while (1) {
        syslog(LOG_INFO, "Daemon parent alive, pid=%d", getpid());
        sleep(30);
    }

    closelog();
    return 0;
}
