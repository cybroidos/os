#!/usr/bin/env bash
# Install headless kcd (KDE Connect v8) into a rootfs.
#
# Debian does not ship kcd yet, so the official upstream .deb is downloaded and
# verified against a pinned SHA-256 checksum. If a future Debian release packages
# kcd, apt is used instead. No secrets, no unauthenticated binaries.
#
# Usage: install-kcd.sh ROOTFS DEB_ARCH WORK_DIR
# Env: KCD_VERSION (2.0.1), KCD_SHA256 (override for a different version),
#      KCD_RELEASE_BASE (https://github.com/bethropolis/kcd/releases/download)
set -euo pipefail

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

[ "$#" -eq 3 ] || die "usage: $0 ROOTFS DEB_ARCH WORK_DIR"
rootfs="$1"; deb_arch="$2"; work_dir="$3"
[ -d "${rootfs}" ] || die "rootfs not found: ${rootfs}"
mkdir -p "${work_dir}"

kcd_version="${KCD_VERSION:-2.0.1}"
kcd_base="${KCD_RELEASE_BASE:-https://github.com/bethropolis/kcd/releases/download}"
expected_sha="${KCD_SHA256:-309b6b2787bc61d6857a5a90086bf83f1c48fc2a20cc3826e5a070c0066dabc5}"
if [ "${kcd_version}" != "2.0.1" ] && [ -z "${KCD_SHA256:-}" ]; then
	die "set KCD_SHA256 when KCD_VERSION is not 2.0.1 (no unverified downloads)"
fi

case "${deb_arch}" in
	amd64) asset_arch="x86_64" ;;
	arm64) asset_arch="aarch64" ;;
	*) die "no upstream kcd .deb for architecture '${deb_arch}'" ;;
esac

# Prefer a Debian package if one ever becomes available.
candidate="$(chroot "${rootfs}" apt-cache policy kcd 2>/dev/null \
	| awk '/Candidate:/ {print $2; exit}')"
if [[ "${candidate:-}" =~ ^[0-9] ]]; then
	echo "Installing kcd ${candidate} from apt"
	chroot "${rootfs}" /usr/bin/env DEBIAN_FRONTEND=noninteractive \
		apt-get install -y --no-install-recommends kcd
	exit 0
fi

asset="kcd_${kcd_version}_${asset_arch}.deb"
url="${kcd_base}/v${kcd_version}/${asset}"
deb="${work_dir}/${asset}"
command -v curl >/dev/null 2>&1 || die "curl is required to fetch kcd"
command -v sha256sum >/dev/null 2>&1 || die "sha256sum is required to verify kcd"

echo "Fetching official kcd ${kcd_version} (${asset})"
curl -fsSL --retry 3 -o "${deb}" "${url}"
actual_sha="$(sha256sum "${deb}" | awk '{print $1}')"
[ "${actual_sha}" = "${expected_sha}" ] \
	|| die "kcd checksum mismatch: expected ${expected_sha}, got ${actual_sha} (URL: ${url})"
echo "kcd SHA-256 verified: ${actual_sha}"

mkdir -p "${rootfs}/var/cache/cybroidos"
cp "${deb}" "${rootfs}/var/cache/cybroidos/${asset}"
chroot "${rootfs}" /usr/bin/env DEBIAN_FRONTEND=noninteractive \
	dpkg -i "/var/cache/cybroidos/${asset}"
rm -f "${rootfs}/var/cache/cybroidos/${asset}"
chroot "${rootfs}" /bin/sh -c 'command -v kcd' >/dev/null 2>&1 \
	|| die "kcd binary was not installed by ${asset}"
