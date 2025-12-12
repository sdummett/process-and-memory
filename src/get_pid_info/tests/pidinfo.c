#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/syscall.h>
#include <errno.h>
#include <string.h>
#include "get_pid_info.h"   // pid_info_t, PROC_STATE_*, get_pid_info()


// Affichage formaté d'une structure pid_info_t
static void print_pid_info(const pid_info_t *info)
{
    printf("PID                : %d\n", info->pid);
    printf("Parent PID         : %d\n", info->parent_pid);
    printf("Age (s)            : %d\n", info->age);
    printf("État               : %s (%d)\n",
           state_to_str(info->state), info->state);
    printf("Stack pointer      : %p\n", info->stack_pointer);
    printf("Root path          : %s\n",
           info->root_path[0] ? info->root_path : "(vide)");
    printf("Current directory  : %s\n",
           info->current_working_directory[0]
               ? info->current_working_directory
               : "(vide)");
}

// Affiche l'erreur pour un PID donné
static void print_error_for_pid(int pid)
{
    if (errno == ESRCH) {
        fprintf(stderr, "Erreur: PID %d introuvable (ESRCH)\n", pid);
    } else if (errno == EINVAL) {
        fprintf(stderr, "Erreur: appel invalide pour PID %d (EINVAL)\n", pid);
    } else if (errno == EFAULT) {
        fprintf(stderr, "Erreur: problème de copie vers l'espace utilisateur pour PID %d (EFAULT)\n", pid);
    } else {
        fprintf(stderr, "Erreur: syscall get_pid_info(%d) a échoué: errno=%d (%s)\n",
                pid, errno, strerror(errno));
    }
}

int main(int argc, char *argv[])
{
    if (argc < 2) {
        fprintf(stderr,
                "Usage: %s <pid1> [pid2] [pid3] ...\n"
                "Affiche les informations renvoyées par le syscall get_pid_info pour chaque PID.\n",
                argv[0]);
        return EXIT_FAILURE;
    }

    int exit_status = 0;

    for (int i = 1; i < argc; ++i) {
        char *endptr = NULL;
        errno = 0;

        long pid_long = strtol(argv[i], &endptr, 10);
        if (errno != 0 || endptr == argv[i] || *endptr != '\0' || pid_long <= 0) {
            fprintf(stderr, "Argument invalide pour le PID: '%s'\n", argv[i]);
            exit_status = 1;
            continue;
        }

        int pid = (int)pid_long;
        pid_info_t info;
        memset(&info, 0, sizeof(info));

        long ret = get_pid_info(&info, pid);
        if (ret != 0) {
            print_error_for_pid(pid);
            exit_status = 1;
            continue;
        }

        printf("========================================\n");
        printf("Informations pour PID %d\n", pid);
        printf("========================================\n");
        print_pid_info(&info);
        printf("\n");
    }

    return exit_status ? EXIT_FAILURE : EXIT_SUCCESS;
}
