#!/usr/bin/env bash
# CIT-OS Server as a container: Proxmox's Debian 13 container template with
# the CIT-OS identity, repacked as a Proxmox (LXC) template. The same tarball
# imports into Docker or Podman too:
#   zstd -dc citos-server_<v>-1_amd64.tar.zst | docker import - citos/server:<v>
#
#   sudo targets/container/build.sh     -> out/citos-server_<version>-1_amd64.tar.zst
#
# Built by CI (.github/workflows/server-images.yml), which uploads it where
# Hangar fetches it from.
# Needs root (to keep file owners), tar, zstd, curl, python3, dpkg-deb.
# Env: BASE (a Proxmox debian-13-standard tarball), OUT (out/).
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "${here}/../.." && pwd)"
# shellcheck source=../lib/image.sh
. "${repo}/targets/lib/image.sh"

[ "$(id -u)" = 0 ] || die "run as root"
need tar zstd curl

out="${OUT:-${repo}/out}"
mkdir -p "${out}"
tarball="${out}/citos-server_${VERSION}-1_amd64.tar.zst"
work="$(mktemp -d)"
root="${work}/root"

cleanup() {
	set +e
	unmount_chroot "${root}"
	rm -rf "${work}"
}
trap cleanup EXIT

# The identity, and apt pointed at citos.cybroid.com (citos-sources).
export CITOS_PACKAGES="citos-base citos-sources"
build_debs $CITOS_PACKAGES

# The base: Proxmox's own template, from its cache or its download server.
base="${BASE:-}"
if [ -z "${base}" ]; then
	base="$(ls /var/lib/vz/template/cache/debian-13-standard_*_amd64.tar.zst 2>/dev/null | sort -V | tail -1 || true)"
fi
if [ -z "${base}" ]; then
	name="$(curl -fsSL http://download.proxmox.com/images/system/ | grep -o 'debian-13-standard_[^"]*_amd64.tar.zst' | sort -uV | tail -1)"
	[ -n "${name}" ] || die "couldn't find Debian 13 on download.proxmox.com"
	base="${out}/${name}"
	[ -f "${base}" ] || curl -fL --retry 3 -o "${base}" "http://download.proxmox.com/images/system/${name}"
fi
echo "Base: ${base}"

mkdir -p "${root}"
tar --numeric-owner -xpf "${base}" -I zstd -C "${root}"

mount_chroot "${root}"
install_citos "${root}" container
unmount_chroot "${root}"
# Proxmox writes the container's own hostname and network at create time.
rm -f "${root}/etc/hostname"

echo "Packing"
tar --numeric-owner -cpf - -C "${root}" . | zstd -q -19 -T0 -o "${tarball}.part"
mv "${tarball}.part" "${tarball}"
echo "Built ${tarball} ($(du -h "${tarball}" | cut -f1))"
