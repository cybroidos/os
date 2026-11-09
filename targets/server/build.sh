#!/usr/bin/env bash
# CIT-OS Server as a VM image: Debian 13's official cloud image (cloud-init,
# a 3 GB disk that grows on first boot) with the CIT-OS identity and the QEMU
# guest agent, as a compressed qcow2. Built by CI (.github/workflows/server-images.yml).
#
#   sudo targets/server/build.sh     -> out/citos-server-<version>-amd64.qcow2
#
# Needs root (loop devices, chroot), qemu-img, curl, python3 and dpkg-deb.
# Env: BASE (a local copy of the Debian cloud image), OUT (out/).
# The desktop (Xfce, xrdp) comes later as its own variant on this base.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "${here}/../.." && pwd)"
# shellcheck source=../lib/image.sh
. "${repo}/targets/lib/image.sh"

[ "$(id -u)" = 0 ] || die "run as root"
need qemu-img losetup curl

base_url="https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2"
out="${OUT:-${repo}/out}"
mkdir -p "${out}"
image="${out}/citos-server-${VERSION}-amd64.qcow2"
work="$(mktemp -d)"
loop="" mnt="${work}/root"

cleanup() {
	set +e
	unmount_chroot "${mnt}"
	mountpoint -q "${mnt}" && umount "${mnt}"
	[ -n "${loop}" ] && losetup -d "${loop}"
	rm -rf "${work}"
}
trap cleanup EXIT

build_debs citos-base

base="${BASE:-${out}/debian-13-genericcloud-amd64.qcow2}"
if [ ! -f "${base}" ]; then
	echo "Downloading Debian 13's cloud image"
	curl -fL --retry 3 -o "${base}.part" "${base_url}" && mv "${base}.part" "${base}"
fi
qemu-img convert -O raw "${base}" "${work}/disk.raw"

# Attach the disk and mount its root partition (the largest ext4 one).
loop="$(losetup -fP --show "${work}/disk.raw")"
udevadm settle 2>/dev/null || sleep 2
part="$(lsblk -lnbo NAME,FSTYPE,SIZE "${loop}" | awk '$2 == "ext4" {print $3, $1}' | sort -n | tail -1 | cut -d' ' -f2)"
[ -n "${part}" ] || die "no root partition in the cloud image"
mkdir -p "${mnt}"
mount "/dev/${part}" "${mnt}"

mount_chroot "${mnt}"
install_citos "${mnt}" server qemu-guest-agent
unmount_chroot "${mnt}"
fstrim "${mnt}" 2>/dev/null || true
umount "${mnt}"
losetup -d "${loop}"
loop=""

echo "Compressing"
qemu-img convert -c -O qcow2 "${work}/disk.raw" "${image}"
echo "Built ${image} ($(du -h "${image}" | cut -f1))"
