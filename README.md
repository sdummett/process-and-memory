# Utilisation du Makefile

Ce projet fournit un `Makefile` qui automatise :

- la récupération des sources du noyau Linux 4.19.322 ;
- l’ajout d’un appel système personnalisé `get_pid_info` ;
- la compilation et l’installation du noyau ;
- la création d’une image rootfs minimale (BusyBox) pour les tests avec QEMU ;
- la création et l’utilisation d’une VM Debian ;
- la compilation et l’injection de binaires de test dans le rootfs.

Toutes les commandes suivantes se lancent depuis la racine du dépôt.

> Attention : certaines cibles exécutent des commandes `sudo`  
> (installation du noyau, mise à jour de GRUB, création de VM, etc.).

---

## 1. Prérequis

Avant d’utiliser le `Makefile`, assurez-vous d’avoir :

- Un environnement Linux x86_64 avec les outils de build classiques :
  - `gcc`, `make`, `wget`, `tar`…
- `qemu-system-x86_64` pour exécuter le noyau/les VM.
- Les droits `sudo` pour :
  - installer un noyau dans `/usr/src` et `/boot` ;
  - mettre à jour `initramfs` et `grub` ;
  - gérer les fichiers dans `/lib/modules`.

---

## 2. Cibles principales

### 2.1 `make` ou `make all`

```bash
make
# ou
make all
```

Cette cible construit et **installe le noyau Linux 4.19.322** dans le système en y ajoutant le syscall `get_pid_info`.

De manière résumée, elle effectue :

1. Téléchargement de l’archive du noyau si nécessaire (`linux-4.19.322.tar.xz`).
2. Décompression et copie des sources vers `/usr/src/linux-4.19.322`.
3. Ajout du fichier `get_pid_info.c` dans l’arborescence du noyau et mise à jour de la table des syscalls.
4. Ajout de `get_pid_info.o` dans `kernel/Makefile` si nécessaire.
5. Configuration du noyau via `defconfig` + activation de `CONFIG_VIRTIO_PCI=y`.
6. Compilation du noyau (`bzImage`) en utilisant tous les cœurs (moins 1).
7. Installation du noyau et des modules dans le système (`/boot`, `/lib/modules`…).
8. Mise à jour de `initramfs` et de `grub`.

Utilisez cette cible si vous souhaitez tester ce noyau personnalisé directement sur la machine (en le sélectionnant ensuite dans le menu de boot).

---

### 2.2 `make dev`

```bash
make dev
```

Cette cible est prévue pour le **développement et les tests rapides** dans une VM QEMU avec un rootfs minimal BusyBox.

Elle réalise notamment :

1. Téléchargement + unpack du noyau dans `/usr/src/linux-4.19.322` si besoin.
2. Configuration du noyau (`defconfig` + `CONFIG_VIRTIO_PCI=y`).
3. Compilation du noyau dans `/usr/src/linux-4.19.322`.
4. Création (ou réinstallation) de l’image rootfs de développement `disks/rootfs.ext4`.
5. Compilation du binaire de test `bin/get_pid_info/tests/test-1`.
6. Injection du binaire de test dans le rootfs.
7. Lancement de QEMU via `./scripts/kernel-exec.sh` avec :
   - le noyau compilé (`arch/x86/boot/bzImage`) ;
   - l’image rootfs `disks/rootfs.ext4`.

Utilisez `make dev` si vous voulez tester le syscall et les binaires associés **sans installer** le noyau dans le système host.

---

### 2.3 `make busybox`

```bash
make busybox
```

Cette cible utilise `QEMU` pour **démarrer le noyau + rootfs BusyBox** déjà construits.

- Elle suppose que le noyau et le rootfs (`disks/rootfs.ext4`) existent déjà.
- Elle appelle le script `./scripts/kernel-exec.sh` avec les bons paramètres.

Pratique pour relancer rapidement l’environnement minimal sans recompiler le noyau.

---

### 2.4 `make test-1-in-busybox`

```bash
make test-1-in-busybox
```

Cette cible :

1. Compile le binaire de test `bin/get_pid_info/tests/test-1` (statiquement, avec les bons `-I` vers `src/get_pid_info/include/`).
2. Ajoute ce binaire dans le rootfs BusyBox via `./scripts/busybox.sh --add`.

Ensuite, en démarrant la VM BusyBox (`make busybox` ou `make dev`), vous pourrez **exécuter ce test depuis l’intérieur de la VM**.

---

### 2.5 `make vm-install`

```bash
make vm-install
```

Cette cible sert à **créer une VM Debian** (image disque) via le script :

```bash
./scripts/vm.sh --install ./disks/debian.img
```

Elle prépare une image `./disks/debian.img` qui pourra ensuite être lancée.

---

### 2.6 `make vm-launch`

```bash
make vm-launch
```

Lance la VM Debian précédemment installée :

```bash
./scripts/vm.sh --launch ./disks/debian.img
```

Utilisez ce couple `vm-install` / `vm-launch` si vous avez besoin d’un environnement Debian plus complet que le rootfs BusyBox minimal.

---

### 2.7 `make remove-linux`

```bash
make remove-linux
```

Supprime le noyau 4.19.322 installé dans le système (fichiers `/boot/vmlinuz-4.19.322`, `/lib/modules/4.19.322`, etc.) et met à jour `initramfs` et `grub`, **à condition que ce noyau ne soit pas celui actuellement en cours d’utilisation**.

Concrètement :

- Si `uname -r` ne contient pas `4.19.322`, les fichiers liés à ce noyau sont supprimés et `update-initramfs` / `update-grub` sont exécutés.
- Sinon, l’opération est annulée avec un message indiquant que le noyau est en cours d’utilisation.

---

## 3. Cibles de nettoyage

### 3.1 `make clean`

```bash
make clean
```

Actuellement, cette cible se contente d’afficher `[CLEAN]`.  
Elle est prévue pour être étendue si besoin (par exemple, nettoyage des builds noyau locaux).

---

### 3.2 `make fclean`

```bash
make fclean
```

Fait un nettoyage plus agressif :

1. Appelle `make clean`.
2. Supprime l’image rootfs de développement :  
   `disks/rootfs.ext4`
3. Supprime l’archive du noyau :  
   `linux-4.19.322.tar.xz`

Utilisez-la pour revenir à un état quasi vierge (mais sans effacer les sources déjà décompressées dans `/usr/src`).

---

## 4. Résumé des workflows typiques

- **Installer le noyau patché sur la machine host**  
  ```bash
  make          # ou make all
  ```
  Puis sélectionner le noyau `4.19.322` au boot.

- **Développer/tester le syscall dans une VM minimaliste**  
  ```bash
  make dev      # compile + lance QEMU sur rootfs BusyBox
  ```
  (recommandé pour éviter de rebooter la machine host).

- **Relancer la VM BusyBox déjà prête**  
  ```bash
  make busybox
  ```

- **Injecter (ou réinjecter) le test `test-1` dans le rootfs**  
  ```bash
  make test-1-in-busybox
  ```

- **Créer puis lancer une VM Debian plus complète**  
  ```bash
  make vm-install
  make vm-launch
  ```

- **Désinstaller le noyau 4.19.322 installé dans le système**  
  ```bash
  make remove-linux
  ```

- **Nettoyer les fichiers générés**  
  ```bash
  make clean    # léger
  make fclean   # plus agressif (supprime aussi l’archive + rootfs)
  ```

---
---

# Documentation des structures et fonctions noyau utilisées dans `get_pid_info`

Ce document décrit les principales **structures**, **fonctions** et **macros** provenant du noyau Linux et utilisées dans l’implémentation du syscall `get_pid_info`.

---

## 1. Structures noyau

### 1.1 `struct task_struct`

- Définie dans `<linux/sched.h>`.
- Représente un **processus** ou un **thread** dans le noyau.
- Contient notamment :
  - les identifiants de process (PID, TGID, etc.) accessibles via des helpers comme `task_pid_nr()`,
  - l’ID du parent via `task_ppid_nr()`,
  - l’état d’ordonnancement (running, sleeping, zombie, etc.),
  - les informations de temps (`start_time`, etc.),
  - un pointeur vers la structure `fs_struct` (`task->fs`),
  - l’adresse de la pile noyau (`task->stack`),
  - les structures de planification, cgroups, etc.

Dans le code, on manipule un `struct task_struct *task` obtenu par `get_pid_task()`.

---

### 1.2 `struct pid`

- Définie dans `<linux/pid.h>`.
- Représente un identifiant de processus dans le noyau, avec gestion de **références**.
- C’est un objet plus riche qu’un simple `int` : il gère les différents espaces de PID, les types (PID de thread, de groupe, etc.).
- On l’obtient par exemple avec `find_vpid(pid)` puis on demande la `task_struct` associée avec `get_pid_task()`.

---

### 1.3 `struct fs_struct`

- Définie dans `<linux/fs_struct.h>`.
- Représente l’état « filesystem » d’un processus :
  - répertoire courant (`pwd`),
  - répertoire racine (`root`) (par ex. après un `chroot`),
  - `umask`,
  - références sur les chemins correspondants.
- Accessible via le champ `task->fs`.
- Certains threads noyau n’ont pas de `fs_struct` (d’où le test `if (!fs)` dans le code).

---

### 1.4 `struct path`

- Définie dans `<linux/path.h>`.
- Représente un chemin dans le VFS (Virtual File System) :
  - un `struct vfsmount *mnt` (montage),
  - un `struct dentry *dentry` (entrée dans la dcache).
- Utilisée avec `get_fs_root()` et `get_fs_pwd()` pour stocker respectivement la racine et le répertoire courant d’un processus.

---

## 2. Temps et horloge

### 2.1 `ktime_get_ns()`

- Renvoie le temps courant de l’horloge **monotone** (MONOTONIC) en **nanosecondes** (`u64`).
- L’horloge monotone ne recule pas et est relative au boot de la machine (avec ajustements monotoniques éventuels).
- Le code l’utilise pour calculer l’âge du processus.

---

### 2.2 `task->start_time`

- Champ de `struct task_struct`.
- Timestamp de création du processus (fork/exec), en nanosecondes.
- En le combinant avec `ktime_get_ns()`, on obtient la durée de vie du process.

---

### 2.3 `NSEC_PER_SEC`

- Macro définissant le nombre de nanosecondes dans une seconde : `1000000000`.
- Permet de convertir un intervalle exprimé en nanosecondes en secondes entières.

---

## 3. PID, tâches et états

### 3.1 `task_state_to_char(struct task_struct *task)`

- Helper défini dans `<linux/sched.h>`.
- Convertit l’état interne du processus (`task->state`, `task->exit_state`, etc.) en un **caractère** :
  - `'R'` : running,
  - `'S'` : sleeping,
  - `'D'` : uninterruptible sleep,
  - `'T'` : stopped/traced,
  - `'Z'` : zombie,
  - etc.
- Le code mappe ce caractère vers l’`enum process_state_e` utilisateur (`PROC_STATE_RUNNING`, `PROC_STATE_SLEEPING`, `PROC_STATE_ZOMBIE`).

---

### 3.2 `task_pid_nr(struct task_struct *task)`

- Helper pour obtenir le **PID** (int) d’un `task_struct` dans l’espace PID visible.
- Évite de gérer directement les structures `struct pid`.
- Utilisé dans le code pour remplir `kpid_info.pid`.

---

### 3.3 `task_ppid_nr(struct task_struct *task)`

- Similaire à `task_pid_nr()`, mais renvoie l’ID du **parent** (PPID).
- Utilisé pour remplir `kpid_info.parent_pid`.

---

### 3.4 `find_vpid(int nr)`

- Définie dans `<linux/pid.h>`.
- Recherche un objet `struct pid *` pour le numéro `nr` dans l’espace global des PID.
- Incrémente le refcount sur l’objet `pid` trouvé.
- Retourne NULL si aucun processus n’a ce PID.

---

### 3.5 `get_pid_task(struct pid *pid, enum pid_type type)`

- Toujours dans `<linux/pid.h>`.
- À partir d’un `struct pid *` et d’un type (`PIDTYPE_PID`, `PIDTYPE_TGID`, etc.), renvoie le `struct task_struct *` associé.
- Incrémente le refcount de la task (comme `get_task_struct()`).
- Retourne NULL si aucune task ne correspond.

---

### 3.6 `PIDTYPE_PID`

- Type de PID utilisé pour désigner un processus ou thread individuel.
- Passé à `get_pid_task()` pour obtenir la task associée à ce PID « classique ».  

---

### 3.7 `put_task_struct(struct task_struct *task)`

- Fonction de gestion de **référence** sur les `task_struct`.
- Décrémente le refcount sur la task obtenu précédemment (ici via `get_pid_task()`).
- Lorsque le refcount atteint zéro, la structure peut être libérée.

---

## 4. RCU et synchronisation

### 4.1 `rcu_read_lock()` / `rcu_read_unlock()`

- Primitives RCU (Read-Copy-Update) pour protéger les lectures sur des données partagées.
- `task->fs` est protégé par RCU ; il doit être accédé sous `rcu_read_lock()`.
- Garantit que la valeur lue ne sera pas libérée tant que la section critique RCU est ouverte.

---

## 5. Fonctions liées au filesystem

### 5.1 `get_fs_root(struct fs_struct *fs, struct path *root)`

- Définie dans `<linux/fs_struct.h>`.
- Récupère la **racine** (`root`) du process (éventuellement différente de `/` à cause de `chroot`).
- Incrémente les références sur le `struct path` résultat (et sous-jacents).

### 5.2 `get_fs_pwd(struct fs_struct *fs, struct path *pwd)`

- Également dans `<linux/fs_struct.h>`.
- Récupère le **répertoire courant** (`pwd`) du process.
- Prend une référence sur le `struct path` retourné.

---

### 5.3 `d_path(const struct path *path, char *buf, int buflen)`

- Fonction du VFS qui convertit un `struct path` en **chemin absolu** lisible.
- Retourne un pointeur dans le buffer `buf` ou un pointeur d’erreur (encodé via `ERR_PTR()`).
- Utilisée pour répercuter les chemins root et cwd dans la struct utilisateur.

---

### 5.4 `path_put(struct path *path)`

- Libère une référence sur un `struct path` obtenue par `get_fs_root()` ou `get_fs_pwd()`.
- Décrémente les refcounts sur la dentry et le vfsmount associés.

---

### 5.5 `PATH_MAX`

- Constante définissant la taille maximale d’un chemin dans le noyau.
- Utilisée pour allouer le buffer temporaire passé à `d_path()`.

---

## 6. Allocation mémoire noyau

### 6.1 `kmalloc(size_t size, gfp_t flags)`

- Fonction d’allocation mémoire en espace noyau.
- `GFP_KERNEL` : allocation standard, autorisée à dormir (contexte process).
- Retourne un pointeur valide ou `NULL` en cas d’échec.

---

### 6.2 `kfree(const void *objp)`

- Libération de mémoire précédemment allouée par `kmalloc` ou équivalent.

---

### 6.3 `GFP_KERNEL`

- Flag passé à `kmalloc` pour indiquer un contexte d’allocation « normal » côté noyau (peut dormir / faire du reclaim).

---

## 7. Accès espace utilisateur / noyau

### 7.1 `copy_to_user(void __user *to, const void *from, unsigned long n)`

- Définie dans `<linux/uaccess.h>`.
- Copie `n` octets depuis l’espace noyau (`from`) vers l’espace utilisateur (`to`).
- Vérifie la validité de l’adresse utilisateur et gère les fautes de page.
- Retourne le nombre d’octets **non copiés** (0 si succès).

---

### 7.2 Annotation `__user`

- Utilisée dans `struct pid_info __user *upid_info`.
- Indique qu’il s’agit d’un pointeur vers l’espace **utilisateur**.
- Aide les outils d’analyse statique et de vérification de sécurité à détecter les erreurs d’usage.

---

## 8. Infrastructure syscall et logging

### 8.1 `SYSCALL_DEFINE2`

- Macro définie dans `<linux/syscalls.h>` pour déclarer un syscall avec 2 arguments.
- Exemple :

```c
SYSCALL_DEFINE2(get_pid_info,
                struct pid_info __user *, upid_info,
                int, pid)
```

- Génère la fonction avec la bonne signature et l’intègre à la table des syscalls (selon l’architecture et la configuration).

---

### 8.2 `pr_info(...)` et `pr_err(...)`

- Macros de **log noyau** :
  - `pr_info` : messages d’information,
  - `pr_err` : messages d’erreur.
- S’appuient sur `printk` en interne.
- Les messages sont visibles via `dmesg` ou le journal du système.

---

### 8.3 Codes d’erreur `-EINVAL`, `-ESRCH`, `-EFAULT`

- Valeurs standard d’erreurs dans le noyau (définies dans `<linux/errno.h>`), renvoyées par les syscalls :
  - `-EINVAL` : argument invalide (par ex. `upid_info == NULL`),
  - `-ESRCH` : processus introuvable (`find_vpid` ou `get_pid_task` a échoué),
  - `-EFAULT` : adresse utilisateur invalide ou non accessible (échec de `copy_to_user`).

---

## 9. Fonctions utilitaires de chaîne et mémoire

### 9.1 `memset(void *s, int c, size_t n)`

- Initialise une zone mémoire à la valeur `c` sur `n` octets.
- Utilisée pour zero-iser la structure `kpid_info` avant remplissage.

---

### 9.2 `strlcpy(char *dst, const char *src, size_t size)`

- Copie une chaîne de `src` vers `dst` avec limite de taille, en garantissant la terminaison `\00` si `size > 0`.
- Plus sûre que `strcpy`, évite les dépassements de buffer (troncation contrôlée).

---

### 9.3 `IS_ERR(ptr)`

- Macro pour tester si un pointeur encode une **erreur**.
- Certaines fonctions (comme `d_path`) renvoient soit un pointeur valide, soit un pointeur d’erreur créé avec `ERR_PTR(-errno)`.
- `IS_ERR(p)` permet de distinguer les deux cas.

---

## 10. Champ `task->stack`

- Champ de `struct task_struct` qui pointe vers la **pile noyau** du thread/process.
- Dans votre code, il est utilisé pour renseigner `kpid_info.stack_pointer`.
- C’est une adresse en espace noyau, uniquement utile pour le debug / diagnostic, pas exploitable directement en espace utilisateur.
