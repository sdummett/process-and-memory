#!/bin/bash

# Ce script permet de setup et entrer dans un environnement
# dans lequel on va chroot afin de demontrer le changement
# de root_path du processus qui y sera
# grace a la structure que nous renverra le syscall get_pid_info()

# (1) creer l’arborescence nécessaire
sudo mkdir -p jailed/{bin,lib,lib64,usr/lib,x86_64-linux-gnu}

# (2) copier bash
sudo cp -v /bin/bash jailed/bin/

# (3) copier le loader + toutes les libs dont bash dépend
ldd /bin/bash | awk '{print $3}' | grep '^/' | while read -r f; do
  sudo cp -v --parents "$f" jailed/
done

# le loader n'apparaît pas toujours dans la colonne $3, on le copie explicitement
sudo cp -v --parents /lib64/ld-linux-x86-64.so.2 jailed/ 2>/dev/null || true
# (selon distro, ça peut être ailleurs)
sudo cp -v --parents /lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 jailed/ 2>/dev/null || true

sudo chroot jailed /bin/bash
