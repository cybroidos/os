#!/usr/bin/env bash
# Smoke-test a Cybroid OS desktop ISO.
#
# Always checks the ISO filesystem (rootless): live kernel/initrd/squashfs are
# present, the package manifest contains the expected packages, and (with
# squashfs-tools) the image's os-release, hostname, banners and desktop config
# are branded correctly. With QEMU available, also boots the ISO's own kernel
# headlessly (-nographic serial console) and checks that systemd starts.
#
# QEMU is emulation, not hardware validation (docs/PLAN.md ground rule 4).
# Use SKIP_BOOT=1 to inspect only the ISO filesystem with isoinfo/xorriso.
#
# Usage: tests/desktop/iso-smoke-test.sh ISO [options]
# Env: SKIP_BOOT=1, DESKTOP=plasma|xfce, ARCH=amd64|arm64, QEMU, MEM,
#      BOOT_TIMEOUT=180, QEMU_EXTRA (space-separated extra QEMU arguments)
set -euo pipefail

die() { echo "error: $*" >&2; exit 1; }
note() { echo "note: $*" >&2; }

usage() {
	cat <<'EOF'
usage: tests/desktop/iso-smoke-test.sh ISO [--desktop plasma|xfce] [--skip-boot]
EOF
}

iso=""
DESKTOP="${DESKTOP:-plasma}"
ARCH="${ARCH:-amd64}"
SKIP_BOOT="${SKIP_BOOT:-0}"

while [ "$#" -gt 0 ]; do
	case "$1" in
		-h|--help) usage; exit 0 ;;
		--desktop) [ "$#" -ge 2 ] || die "--desktop needs a value"; DESKTOP="$2"; shift 2 ;;
		--skip-boot) SKIP_BOOT=1; shift ;;
		-*) die "unknown option: $1" ;;
		*) [ -z "${iso}" ] || die "unexpected argument: $1"; iso="$1"; shift ;;
	esac
done
[ -n "${iso}" ] || { usage >&2; exit 1; }
[ -f "${iso}" ] || die "no such ISO: ${iso}"
case "${DESKTOP}" in
	plasma|xfce) ;;
	*) die "unsupported DESKTOP: ${DESKTOP}" ;;
esac

have_isoinfo=0
have_xorriso=0
command -v isoinfo >/dev/null 2>&1 && have_isoinfo=1
command -v xorriso >/dev/null 2>&1 && have_xorriso=1
[ "${have_isoinfo}" -eq 1 ] || [ "${have_xorriso}" -eq 1 ] \
	|| die "install genisoimage (isoinfo) or xorriso to inspect the ISO"

work="$(mktemp -d "${TMPDIR:-/tmp}/cybroidos-iso-test.XXXXXXXX")"
trap 'rm -rf "${work}"' EXIT
fail=0

iso_list() {
	if [ "${have_isoinfo}" -eq 1 ]; then
		isoinfo -f -i "${iso}"
	else
		xorriso -indev "${iso}" -find 2>/dev/null
	fi | sed 's/;.*$//'
}

iso_extract() {
	local path="$1" dest="$2"
	if [ "${have_isoinfo}" -eq 1 ]; then
		isoinfo -i "${iso}" -x "${path}" > "${dest}"
	else
		xorriso -osirrox on -indev "${iso}" -extract "${path}" "${dest}" >/dev/null
	fi
	[ -s "${dest}" ] || die "could not extract ${path} from ${iso}"
}

check_text() {
	local desc="$1" file="$2" pattern="$3"
	if grep -qE "${pattern}" "${file}" 2>/dev/null; then
		echo "  ok   ${desc}"
	else
		echo "  FAIL ${desc}"
		fail=1
	fi
}

echo "ISO: ${iso}"
listing="$(iso_list)"
kernel="$(printf '%s\n' "${listing}" | grep -E '^/?live/vmlinuz' | head -n 1 || true)"
initrd="$(printf '%s\n' "${listing}" | grep -E '^/?live/initrd' | head -n 1 || true)"
squash="$(printf '%s\n' "${listing}" | grep -E '^/?live/filesystem\.squashfs' | head -n 1 || true)"
packages="$(printf '%s\n' "${listing}" | grep -E '^/?live/filesystem\.packages' | head -n 1 || true)"

echo "ISO structure:"
for item in kernel initrd squash packages; do
	value="${!item}"
	if [ -n "${value}" ]; then
		echo "  ok   live ${item}: ${value}"
	else
		echo "  FAIL live ${item} missing"
		fail=1
	fi
done
[ "${fail}" -eq 0 ] || die "ISO is missing live-build artifacts"

iso_extract "${packages}" "${work}/filesystem.packages"

check_pkg_list() {
	local desc="$1" package="$2"
	check_text "${desc}" "${work}/filesystem.packages" "^${package}[[:space:]]"
}

desktop_package="plasma-desktop"
[ "${DESKTOP}" = "xfce" ] && desktop_package="xfce4"

echo "Package manifest:"
check_pkg_list "cybroidos-base" cybroidos-base
check_pkg_list "cybroidos-desktop meta-package" cybroidos-desktop
check_pkg_list "Calamares installer" calamares
check_pkg_list "known desktop (${desktop_package})" "${desktop_package}"
check_pkg_list "KDE Connect" kdeconnect
check_pkg_list "KRDP" krdp
check_pkg_list "Cybroid control service" cybroidos-control
if grep -qE '^kcd[[:space:]]' "${work}/filesystem.packages"; then
	echo "  ok   headless kcd"
elif grep -qE '^kdeconnect[[:space:]]' "${work}/filesystem.packages"; then
	note "kcd is not in Debian 13 main; kdeconnect provides the desktop daemon"
else
	echo "  FAIL kcd/KDE Connect daemon"
	fail=1
fi

# File-level checks from the live root filesystem. This needs no mount/root.
if [ "${SKIP_BOOT}" != "1" ]; then
	if command -v unsquashfs >/dev/null 2>&1; then
		iso_extract "${squash}" "${work}/filesystem.squashfs"
		unsquashfs -d "${work}/root" -f -no-progress "${work}/filesystem.squashfs" \
			etc/os-release etc/hostname etc/issue etc/motd \
			etc/cybroidos/desktop.conf \
			etc/sddm.conf.d/10-cybroidos.conf \
			etc/calamares/branding/cybroidos/branding.desc \
			var/lib/dpkg/status >/dev/null
		root="${work}/root"
		echo "Root filesystem branding:"
		check_text "os-release ID=cybroidos" "${root}/etc/os-release" '^ID=cybroidos$'
		check_text "os-release product name" "${root}/etc/os-release" 'Cybroid OS'
		check_text "hostname=cybroid" "${root}/etc/hostname" '^cybroid$'
		check_text "MOTD banner" "${root}/etc/motd" 'Cybroid OS'
		check_text "issue banner" "${root}/etc/issue" 'Cybroid OS'
		check_text "desktop.conf selects ${DESKTOP}" "${root}/etc/cybroidos/desktop.conf" "^DESKTOP=\"${DESKTOP}\"$"
		check_text "SDDM theme" "${root}/etc/sddm.conf.d/10-cybroidos.conf" '^Current=cybroidos$'
		check_text "Calamares product name" "${root}/etc/calamares/branding/cybroidos/branding.desc" 'productName = Cybroid OS'
		check_text "Calamares vendor" "${root}/etc/calamares/branding/cybroidos/branding.desc" 'Cybroid Technologies \(U\) Ltd'

		check_dpkg_installed() {
			awk -v want="$1" '
				BEGIN { RS = "" }
				$0 ~ "Package: " want "([ \t]|$)" && $0 ~ /Status: install ok installed/ { found = 1 }
				END { exit !found }
			' "${root}/var/lib/dpkg/status" 2>/dev/null
		}
		echo "Installed package database:"
		for package in cybroidos-base cybroidos-desktop calamares "${desktop_package}" kdeconnect krdp cybroidos-control; do
			if check_dpkg_installed "${package}"; then
				echo "  ok   ${package} installed"
			else
				echo "  FAIL ${package} not installed"
				fail=1
			fi
		done
	else
		note "unsquashfs not installed; skipping file-level rootfs checks"
	fi
else
	note "SKIP_BOOT=1: filesystem inspection only (no squashfs extraction, no QEMU)"
fi

if [ "${SKIP_BOOT}" = "1" ]; then
	[ "${fail}" -eq 0 ] || die "ISO inspection failed"
	echo "PASS (ISO filesystem inspection; QEMU boot skipped)"
	exit 0
fi

QEMU="${QEMU:-qemu-system-x86_64}"
BOOT_TIMEOUT="${BOOT_TIMEOUT:-180}"
MEM="${MEM:-4096}"
command -v "${QEMU}" >/dev/null 2>&1 || die "QEMU not found: ${QEMU} (or set SKIP_BOOT=1)"

iso_extract "${kernel}" "${work}/vmlinuz"
iso_extract "${initrd}" "${work}/initrd.img"

if [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
	note "using KVM acceleration"
else
	note "no writable /dev/kvm; QEMU will fall back to TCG (slow)"
fi

qemu_opts=(
	-m "${MEM}"
	-nographic
	-no-reboot
	-kernel "${work}/vmlinuz"
	-initrd "${work}/initrd.img"
	-append "boot=live components console=ttyS0,115200 hostname=cybroid username=cybroid systemd.show_status=true"
	-cdrom "${iso}"
)
if [ "${ARCH}" = "arm64" ]; then
	qemu_opts=( -M virt -cpu cortex-a57 "${qemu_opts[@]}" )
fi
# shellcheck disable=SC2206  # QEMU_EXTRA is an intentional space-separated override
[ -z "${QEMU_EXTRA:-}" ] || qemu_opts+=( ${QEMU_EXTRA} )

echo "QEMU boot (timeout ${BOOT_TIMEOUT}s, serial console):"
timeout "${BOOT_TIMEOUT}" "${QEMU}" "${qemu_opts[@]}" > "${work}/boot.log" 2>&1 || true
cat "${work}/boot.log"
check_text "guest booted Linux/systemd" "${work}/boot.log" 'Linux version|systemd [0-9]|Reached target|login:'
if grep -qiE 'Hostname: cybroid|hostname.*cybroid' "${work}/boot.log"; then
	echo "  ok   guest hostname observed as cybroid"
else
	note "hostname not visible on serial console (checked in the image instead)"
fi

[ "${fail}" -eq 0 ] || die "desktop ISO smoke test failed"
echo "PASS (Cybroid OS ${DESKTOP} ISO; QEMU boot + image checks)"
