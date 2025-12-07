#!/bin/bash

# -e : stop si une commande echoue
# -u : variables non definies interdites
# -o : pipefail : un pipe echoue si une commande au milieu se plante
set -euo pipefail

usage() {
    echo "Usage: $0 <LINUX_TREE> <SYSCALL_NAME> <SYSCALL_USERSPACE_HEADER> <SYSCALL_KERNELSPACE_SRC>" >&2
    echo
    echo "  LINUX_TREE               : racine des sources du noyau (ex: ~/linux-4.y)"
    echo "  SYSCALL_NAME             : nom du syscall (ex: get_pid_info)"
    echo "  SYSCALL_USERSPACE_HEADER : header userspace a modifier (#ifndef __NR_ / #define __NR_)"
    echo "  SYSCALL_KERNELSPACE_SRC  : fichier .c côte kernel a copier dans LINUX_TREE/kernel"
    exit 1
}

if [[ $# -ne 4 ]]; then
    usage
fi

LINUX_TREE=$1
SYSCALL_NAME=$2
SYSCALL_USERSPACE_HEADER=$3
SYSCALL_KERNELSPACE_SRC=$4

SYSCALL_TBL="$LINUX_TREE/arch/x86/entry/syscalls/syscall_64.tbl"
KERNEL_DIR="$LINUX_TREE/kernel"
KERNEL_MK="$KERNEL_DIR/Makefile"
KERNEL_DST_SRC="$KERNEL_DIR/${SYSCALL_NAME}.c"

# verifs de base
if [[ ! -d "$LINUX_TREE" ]]; then
    echo "$0: Erreur : LINUX_TREE '$LINUX_TREE' n'est pas un repertoire." >&2
    exit 1
fi

if [[ ! -f "$SYSCALL_TBL" ]]; then
    echo "$0: Erreur : syscall_64.tbl introuvable : $SYSCALL_TBL" >&2
    exit 1
fi

if [[ ! -f "$SYSCALL_USERSPACE_HEADER" ]]; then
    echo "$0: Erreur : header userspace introuvable : $SYSCALL_USERSPACE_HEADER" >&2
    exit 1
fi

if [[ ! -f "$SYSCALL_KERNELSPACE_SRC" ]]; then
    echo "$0: Erreur : source kernel introuvable : $SYSCALL_KERNELSPACE_SRC" >&2
    exit 1
fi

if [[ ! -f "$KERNEL_MK" ]]; then
    echo "$0: Erreur : kernel/Makefile introuvable : $KERNEL_MK" >&2
    exit 1
fi

# verifier que le syscall n'existe pas deja dans la table
if grep -Eq "^[[:space:]]*[0-9]+[[:space:]]+[^[:space:]]+[[:space:]]+$SYSCALL_NAME([[:space:]]|\$)" "$SYSCALL_TBL"; then
    echo "$0: Erreur : le syscall '$SYSCALL_NAME' existe deja dans $SYSCALL_TBL" >&2
    exit 0
fi

# recuperer le dernier numero de syscall utilise, et prendre le suivant
LAST_NUM=$(awk '
    !/^#/ && NF >= 1 && $1 ~ /^[0-9]+$/ { last = $1 }
    END { if (last == "") last = -1; print last }
' "$SYSCALL_TBL")

NEW_NUM=$((LAST_NUM + 1))

echo "$0: Dernier syscall = $LAST_NUM, nouveau = $NEW_NUM"

# parano : verifier que NEW_NUM n'est pas déja utilisé
if grep -Eq "^[[:space:]]*$NEW_NUM[[:space:]]" "$SYSCALL_TBL"; then
    echo "$0: Erreur interne : le numéro $NEW_NUM est déja utilisé dans $SYSCALL_TBL" >&2
    exit 1
fi

MACRO_NAME="__NR_${SYSCALL_NAME}"
ENTRY_SYM="__x64_sys_${SYSCALL_NAME}"

# (1) Ajouter la ligne dans syscall_64.tbl
LINE=$(printf "%-4d\tcommon\t%-24s\t%s\n" "$NEW_NUM" "$SYSCALL_NAME" "$ENTRY_SYM")

echo "$0: Ajout dans $SYSCALL_TBL :"
echo "    $LINE"

printf "%s\n" "$LINE" >> "$SYSCALL_TBL"

# (2) mettre a jour le header userspace
if ! grep -q '#ifndef __NR_' "$SYSCALL_USERSPACE_HEADER"; then
    echo "$0: Avertissement : '#ifndef __NR_' introuvable dans $SYSCALL_USERSPACE_HEADER" >&2
fi

if ! grep -q '#define __NR_' "$SYSCALL_USERSPACE_HEADER"; then
    echo "$0: Avertissement : '#define __NR_' introuvable dans $SYSCALL_USERSPACE_HEADER" >&2
fi

sed -i \
    -e "s/^#ifndef __NR_.*$/#ifndef ${MACRO_NAME}/" \
    -e "s/^#define __NR_.*$/#define ${MACRO_NAME} ${NEW_NUM}/" \
    "$SYSCALL_USERSPACE_HEADER"

echo "$0: Mise a jour de $SYSCALL_USERSPACE_HEADER :"
echo "    #ifndef ${MACRO_NAME}"
echo "    #define ${MACRO_NAME} ${NEW_NUM}"

# (3) copier la source kernel dans LINUX_TREE/kernel/<SYSCALL_NAME>.c
if [[ -f "$KERNEL_DST_SRC" ]]; then
    echo "$0: Erreur : $KERNEL_DST_SRC existe deja. Je refuse d'ecraser." >&2
    exit 0
fi

cp "$SYSCALL_KERNELSPACE_SRC" "$KERNEL_DST_SRC"

echo "$0: Copie de $SYSCALL_KERNELSPACE_SRC -> $KERNEL_DST_SRC"

# (4) ajouter l'entree obj-y dans kernel/Makefile si absente
MAKE_LINE="obj-y += ${SYSCALL_NAME}.o"

if grep -Fxq "$MAKE_LINE" "$KERNEL_MK"; then
    echo "$0: Ligne deja presente dans $KERNEL_MK :"
    echo "    $MAKE_LINE"
else
    echo "$0: Ajout dans $KERNEL_MK :"
    echo "    $MAKE_LINE"
    echo "$MAKE_LINE" >> "$KERNEL_MK"
fi

echo "$0: Termine."
