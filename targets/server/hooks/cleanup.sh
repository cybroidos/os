#!/usr/bin/env bash
# Clean a server rootfs before it is written to disk.
#
# Usage: cleanup.sh ROOTFS
# Removes apt caches/logs and all per-instance identity so every clone gets a
# fresh machine-id, fresh SSH host keys and a fresh cloud-init first boot.
set -euo pipefail

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

[ "$#" -eq 1 ] || die "usage: $0 ROOTFS"
rootfs="$1"
[ -d "${rootfs}" ] || die "rootfs not found: ${rootfs}"

echo "Cleaning apt cache, logs and per-instance identity in ${rootfs}"
chroot "${rootfs}" /usr/bin/apt-get clean
find "${rootfs}/var/lib/apt/lists" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} + 2>/dev/null || true

# Drop build-time logs and temporary files (never the rootfs itself).
find "${rootfs}/var/log" -type f \( -name '*.log' -o -name '*.log.*' \) -delete 2>/dev/null || true
find "${rootfs}/tmp" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} + 2>/dev/null || true

# Empty machine-id lets systemd run ConditionFirstBoot units; our first-boot
# script and cloud-init then write a unique one on the VM's first boot.
: > "${rootfs}/etc/machine-id"
rm -f "${rootfs}/var/lib/dbus/machine-id"
mkdir -p "${rootfs}/var/lib/dbus"
ln -sf /etc/machine-id "${rootfs}/var/lib/dbus/machine-id"
find "${rootfs}/etc/ssh" -maxdepth 1 -name 'ssh_host_*' -delete 2>/dev/null || true
rm -rf "${rootfs}/var/lib/cloud/instance" "${rootfs}/var/lib/cloud/instances"
rm -rf "${rootfs}/var/lib/cloud/data" "${rootfs}/var/lib/cloud/seed"

echo "Cleanup complete"
