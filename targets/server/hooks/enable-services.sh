#!/usr/bin/env bash
# Enable Cybroid OS server services offline (no running systemd required).
#
# Usage: enable-services.sh ROOTFS
# Symlinks are created in multi-user.target.wants so they survive in the image;
# a missing unit is an error rather than a silently disabled service.
set -euo pipefail

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

[ "$#" -eq 1 ] || die "usage: $0 ROOTFS"
rootfs="$1"
[ -d "${rootfs}" ] || die "rootfs not found: ${rootfs}"

want="${rootfs}/etc/systemd/system/multi-user.target.wants"
mkdir -p "${want}"

enable_unit() {
	local unit="$1" candidate
	for candidate in "/etc/systemd/system/${unit}" "/lib/systemd/system/${unit}" \
		"/usr/lib/systemd/system/${unit}"; do
		if [ -f "${rootfs}${candidate}" ]; then
			ln -sfn "${candidate}" "${want}/${unit}"
			echo "enabled ${unit} -> ${candidate}"
			return 0
		fi
	done
	die "unit not found in rootfs: ${unit}"
}

for unit in \
	ssh.service \
	xrdp.service \
	xrdp-sesman.service \
	cloud-init.service \
	cloud-init-local.service \
	cloud-config.service \
	cloud-final.service \
	cybroidos-first-boot.service \
	cybroidos-xfce-session.service \
	cybroidos-kcd.service; do
	enable_unit "${unit}"
done
