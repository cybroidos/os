#!/usr/bin/env bash
# CybroidOS Server as a VM image: Debian 13's official cloud image (cloud-init,
# a 3 GB disk that grows on first boot) with the CybroidOS identity and the QEMU
# guest agent, as a compressed qcow2. Built by CI (.github/workflows/server-images.yml).
#
#   sudo targets/server/build.sh                    -> out/cybroid-server-<version>-amd64.qcow2
#   sudo VARIANT=desktop targets/server/build.sh    -> out/cybroid-desktop-<version>-amd64.qcow2
#
# CybroidOS Desktop is KDE Plasma 6 in the CybroidOS Horizon look (cybroid-plasma,
# with the CybroidOS boot splash). It grows the disk to 10 GB and
# swaps Debian's cloud kernel, which has no display drivers, for its
# standard one.
#
# Needs root (loop devices, chroot), qemu-img, curl, python3 and dpkg-deb;
# the desktop also growpart (cloud-guest-utils), e2fsprogs and rsvg-convert.
# Env: BASE (a local copy of the Debian cloud image), OUT (out/), VARIANT.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "${here}/../.." && pwd)"
# shellcheck source=../lib/image.sh
. "${repo}/targets/lib/image.sh"

[ "$(id -u)" = 0 ] || die "run as root"
need qemu-img losetup curl
VARIANT=${VARIANT:-server}
case "$VARIANT" in server | desktop) ;; *) die "VARIANT is server or desktop" ;; esac
GUI=false
[ "$VARIANT" != server ] && GUI=true
$GUI && need growpart resize2fs e2fsck

base_url="https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2"
out="${OUT:-${repo}/out}"
mkdir -p "${out}"
image="${out}/cybroid-${VARIANT}-${VERSION}-amd64.qcow2"
work="$(build_dir 6)"
loop="" mnt="${work}/root"

cleanup() {
	set +e
	unmount_chroot "${mnt}"
	mountpoint -q "${mnt}" && umount "${mnt}"
	[ -n "${loop}" ] && losetup -d "${loop}"
	rm -rf "${work}"
}
trap cleanup EXIT

case "$VARIANT" in
desktop) export CYBROID_PACKAGES="cybroid-base cybroid-sources cybroid-artwork cybroid-plymouth-theme cybroid-plasma" ;;
*) export CYBROID_PACKAGES="cybroid-base cybroid-sources" ;;
esac
build_debs $CYBROID_PACKAGES

base="${BASE:-${out}/debian-13-genericcloud-amd64.qcow2}"
if [ ! -f "${base}" ]; then
	echo "Downloading Debian 13's cloud image"
	curl -fL --retry 5 --retry-all-errors --retry-delay 10 -o "${base}.part" "${base_url}" && mv "${base}.part" "${base}"
fi
qemu-img convert -O raw "${base}" "${work}/disk.raw"
# The desktop needs room: 8 GB, the root partition and filesystem grown to fill it.
case "$VARIANT" in
desktop) qemu-img resize -q -f raw "${work}/disk.raw" 10G ;;
esac

# Attach the disk and mount its root partition (the largest ext4 one).
loop="$(losetup -fP --show "${work}/disk.raw")"
udevadm settle 2>/dev/null || sleep 2
part="$(lsblk -lnbo NAME,FSTYPE,SIZE "${loop}" | awk '$2 == "ext4" {print $3, $1}' | sort -n | tail -1 | cut -d' ' -f2)"
[ -n "${part}" ] || die "no root partition in the cloud image"
if $GUI; then
	growpart "${loop}" "${part##*p}"
	partx -u "${loop}" 2>/dev/null || true
	udevadm settle 2>/dev/null || sleep 2
	e2fsck -fy "/dev/${part}" >/dev/null || true
	resize2fs "/dev/${part}" >/dev/null
fi
mkdir -p "${mnt}"
mount "/dev/${part}" "${mnt}"

mount_chroot "${mnt}"
if $GUI; then
	install_cybroid "${mnt}" desktop qemu-guest-agent linux-image-amd64
	# The standard kernel only: the cloud one would stay first in the boot menu.
	chroot "${mnt}" /usr/bin/env DEBIAN_FRONTEND=noninteractive LC_ALL=C.UTF-8 sh -ec '
		apt-get purge -y -q "linux-image-cloud-amd64" $(dpkg-query -W -f "\${Package}\n" "linux-image-*-cloud-amd64" 2>/dev/null) >/dev/null
		apt-get autoremove -y -q --purge >/dev/null
		grep -q "^menuentry\|linux.*-amd64" /boot/grub/grub.cfg
		ls /boot/vmlinuz-*
	'
else
	install_cybroid "${mnt}" server qemu-guest-agent
fi
unmount_chroot "${mnt}"
fstrim "${mnt}" 2>/dev/null || true
for try in 1 2 3 4 5; do
	umount "${mnt}" && break
	[ "${try}" = 5 ] && { fuser -vm "${mnt}" || true; exit 1; }
	sleep 3
done
losetup -d "${loop}"
loop=""

echo "Compressing"
qemu-img convert -c -O qcow2 "${work}/disk.raw" "${image}"
echo "Built ${image} ($(du -h "${image}" | cut -f1))"
