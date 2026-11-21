#!/usr/bin/env bash
# Install the locally built Cybroid OS .debs into a rootfs.
#
# Usage: install-local-debs.sh ROOTFS BASE_DEB META_DEB
# Fails loudly if either input is missing; never reaches out to the network.
set -euo pipefail

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

[ "$#" -eq 3 ] || die "usage: $0 ROOTFS BASE_DEB META_DEB"
rootfs="$1"; base_deb="$2"; meta_deb="$3"
[ -d "${rootfs}" ] || die "rootfs not found: ${rootfs}"
[ -f "${base_deb}" ] || die "missing base package: ${base_deb}"
[ -f "${meta_deb}" ] || die "missing server metapackage: ${meta_deb}"
command -v chroot >/dev/null 2>&1 || die "chroot is required"

cache="${rootfs}/var/cache/cybroidos"
mkdir -p "${cache}"
cp "${base_deb}" "${cache}/"
cp "${meta_deb}" "${cache}/"
base_name="$(basename "${base_deb}")"
meta_name="$(basename "${meta_deb}")"

echo "Installing ${base_name} and ${meta_name} into ${rootfs}"
chroot "${rootfs}" /usr/bin/env DEBIAN_FRONTEND=noninteractive \
	dpkg -i "/var/cache/cybroidos/${base_name}" "/var/cache/cybroidos/${meta_name}"
# Resolve any dependency ordering left by installing the two packages together.
chroot "${rootfs}" /usr/bin/env DEBIAN_FRONTEND=noninteractive \
	apt-get install -y --no-install-recommends -f
rm -rf "${cache}"
