#!/usr/bin/env bash
# Build the Cybroid OS server/pods image: a Debian 13 x86_64 rootfs containing
# Xfce 4.20, cloud-init, RDP (xrdp) + noVNC fallback, headless kcd and the
# shared Cybroid branding. The rootfs is written to a GPT disk and converted
# to qcow2 with qemu-img; a cloud-init NoCloud seed ISO is produced alongside.
#
# Official, maintained tooling only: mmdebstrap (or debootstrap) for the rootfs,
# apt for packages, qemu-img for the image and genisoimage/xorriso for the seed.
# QEMU-specific workarounds live in tests/server/, never in this image.
#
# Usage: EDITION=core ARCH=x86_64 OUT_DIR=targets/server/deploy \
#          PUBKEY_FILE=/path/to/admin.pub targets/server/build.sh
#
# Env: EDITION (core), ARCH (x86_64|amd64), OUT_DIR (targets/server/deploy),
#      SIZE (8G), WORK_DIR (targets/server/work), SUITE (trixie),
#      MIRROR (http://deb.debian.org/debian), PUBKEY_FILE
#      (editions/${EDITION}/provision.pub by default), RELEASE (trixie),
#      KCD_VERSION/KCD_SHA256 (pinned upstream kcd .deb).
# Requirements: root privileges, mmdebstrap or debootstrap, qemu-utils,
# genisoimage or xorriso, sfdisk, losetup, e2fsprogs, dosfstools, dpkg-dev,
# debhelper, fakeroot, python3, curl and an SSH public key file.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${here}/../.." && pwd)"
hooks="${here}/hooks"
config="${here}/config"

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
note() { printf 'note: %s\n' "$*" >&2; }

EDITION="${EDITION:-core}"
ARCH="${ARCH:-x86_64}"
OUT_DIR="${OUT_DIR:-${here}/deploy}"
SIZE="${SIZE:-8G}"
WORK_DIR="${WORK_DIR:-${here}/work}"
SUITE="${SUITE:-trixie}"
MIRROR="${MIRROR:-http://deb.debian.org/debian}"
RELEASE="${RELEASE:-trixie}"
PUBKEY_FILE="${PUBKEY_FILE:-${repo_root}/editions/${EDITION}/provision.pub}"

case "${ARCH}" in
	x86_64|amd64) image_arch="x86_64"; deb_arch="amd64" ;;
	*) die "the server image supports x86_64 (amd64) only, got '${ARCH}'" ;;
esac
[[ "${SIZE}" =~ ^[0-9]+[KMGTkmgt]?$ ]] || die "SIZE must be a size such as 8G, got '${SIZE}'"
[ "$(id -u)" -eq 0 ] || die "build.sh needs root (mmdebstrap/chroot/loop devices)"

brand="${repo_root}/common/branding/brand.toml"
edition_config="${repo_root}/editions/${EDITION}/config"
[ -f "${brand}" ] || die "missing brand file: ${brand}"
[ -f "${edition_config}" ] || die "unknown edition '${EDITION}' (expected ${edition_config})"
# shellcheck disable=SC1090  # edition config is a trusted, versioned file
. "${edition_config}"
[ -f "${PUBKEY_FILE}" ] || die "missing SSH public key: ${PUBKEY_FILE} (set PUBKEY_FILE)"
grep -Eq '^(ssh-(rsa|ed25519)|ecdsa-sha2-nistp(256|384|521)|sk-ssh-ed25519@openssh\.com|sk-ecdsa-sha2-nistp256@openssh\.com)[[:space:]]+[A-Za-z0-9+/=]+' "${PUBKEY_FILE}" \
	|| die "no valid OpenSSH public key found in ${PUBKEY_FILE}"

version="$(python3 - "${brand}" <<'PY'
import sys, tomllib
with open(sys.argv[1], "rb") as fh:
    print(tomllib.load(fh)["identity"]["version"])
PY
)"
hostname="$(python3 - "${brand}" <<'PY'
import sys, tomllib
with open(sys.argv[1], "rb") as fh:
    print(tomllib.load(fh)["identity"].get("default_hostname", "cybroid"))
PY
)"

# --- Tool preflight (fail early with an actionable message) ------------------
for tool in python3 dpkg-buildpackage mount umount chroot sfdisk losetup \
	mkfs.ext4 mkfs.vfat qemu-img curl sha256sum tar; do
	command -v "${tool}" >/dev/null 2>&1 || die "${tool} is required but not installed"
done
if command -v mmdebstrap >/dev/null 2>&1; then
	bootstrap="mmdebstrap"
elif command -v debootstrap >/dev/null 2>&1; then
	bootstrap="debootstrap"
else
	die "mmdebstrap (preferred) or debootstrap is required"
fi
if command -v genisoimage >/dev/null 2>&1; then
	iso_tool="genisoimage"
elif command -v xorriso >/dev/null 2>&1; then
	iso_tool="xorriso"
else
	die "genisoimage or xorriso is required to build the cloud-init seed ISO"
fi
for hook in apply-branding.sh configure-cloud-init.sh cleanup.sh enable-services.sh \
	install-kcd.sh install-local-debs.sh render-seed.sh; do
	[ -x "${hooks}/${hook}" ] || die "missing executable hook: ${hooks}/${hook}"
done
[ -f "${config}/cloud-init/user-data.tmpl" ] || die "missing cloud-init user-data template"
[ -f "${config}/cloud-init/meta-data.tmpl" ] || die "missing cloud-init meta-data template"

mkdir -p "${OUT_DIR}" "${WORK_DIR}"
rootfs="${WORK_DIR}/rootfs"
render_dir="${WORK_DIR}/branding"
raw="${WORK_DIR}/disk.raw"
mnt="${WORK_DIR}/disk-mnt"
seeddir="${WORK_DIR}/cloud-init-seed"

rm -rf "${rootfs}" "${render_dir}" "${mnt}" "${seeddir}"
mkdir -p "${rootfs}" "${render_dir}" "${mnt}" "${seeddir}"
: > "${raw}"
truncate -s "${SIZE}" "${raw}"

# --- Cleanup state for traps (never touch the caller's filesystem) -----------
mounted_roots=()
loopdev=""
efi_mounted=0
root_mounted=0

unmount_one() {
	# Unmount pseudo-filesystems from one rootfs and forget it in the trap list.
	local target="$1" m
	umount -l "${target}/dev" 2>/dev/null || true
	umount -l "${target}/sys" 2>/dev/null || true
	umount -l "${target}/proc" 2>/dev/null || true
	local kept=()
	for m in "${mounted_roots[@]}"; do
		[ "${m}" = "${target}" ] || kept+=("${m}")
	done
	mounted_roots=("${kept[@]}")
}

unmount_all() {
	local target
	for target in "${mounted_roots[@]}"; do
		umount -l "${target}/dev" 2>/dev/null || true
		umount -l "${target}/sys" 2>/dev/null || true
		umount -l "${target}/proc" 2>/dev/null || true
	done
	if [ "${efi_mounted}" -eq 1 ]; then umount -l "${mnt}/boot/efi" 2>/dev/null || true; fi
	if [ "${root_mounted}" -eq 1 ]; then umount -l "${mnt}" 2>/dev/null || true; fi
	if [ -n "${loopdev}" ]; then losetup -d "${loopdev}" 2>/dev/null || true; fi
}
trap unmount_all EXIT

mount_root() {
	# Bind the host's pseudo-filesystems into a rootfs; safe inside our own
	# WORK_DIR only. Unmounted by the EXIT trap.
	local target="$1"
	mkdir -p "${target}/proc" "${target}/sys" "${target}/dev" "${target}/run"
	mount -t proc proc "${target}/proc"
	mount -t sysfs sysfs "${target}/sys"
	mount --rbind /dev "${target}/dev"
	mount --make-rslave "${target}/dev"
	mounted_roots+=("${target}")
}

chroot_run() {
	# chroot_run ROOTFS COMMAND... — non-interactive apt/systemd-safe helper.
	local target="$1"; shift
	chroot "${target}" /usr/bin/env \
		DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
		LC_ALL=C LANG=C "$@"
}

echo "Building Cybroid OS ${EDITION} server ${image_arch} ${version} (bootstrap: ${bootstrap})"

# --- 1. Branding + shared packages -----------------------------------------
python3 "${repo_root}/tools/render-brand.py" --brand "${brand}" \
	--release "${RELEASE}" --out "${render_dir}"

"${repo_root}/tools/build-package.sh" cybroidos-base
"${repo_root}/tools/build-package.sh" cybroidos-server
base_deb="$(find "${repo_root}/dist" -maxdepth 1 -name "cybroidos-base_${version}_*.deb" -print -quit)"
meta_deb="$(find "${repo_root}/dist" -maxdepth 1 -name "cybroidos-server_${version}_*.deb" -print -quit)"
[ -n "${base_deb}" ] || die "cybroidos-base ${version} .deb was not built in ${repo_root}/dist"
[ -n "${meta_deb}" ] || die "cybroidos-server ${version} .deb was not built in ${repo_root}/dist"

# --- 2. Bootstrap Debian 13 rootfs -----------------------------------------
if [ "${bootstrap}" = mmdebstrap ]; then
	echo "Bootstrapping ${SUITE}/${deb_arch} with mmdebstrap"
	mmdebstrap --mode=root --variant=apt --architectures="${deb_arch}" \
		"${SUITE}" "${rootfs}" "deb ${MIRROR} ${SUITE} main"
else
	echo "Bootstrapping ${SUITE}/${deb_arch} with debootstrap (fallback)"
	debootstrap --arch="${deb_arch}" --variant=minbase "${SUITE}" \
		"${rootfs}" "${MIRROR}"
	printf 'deb %s %s main\n' "${MIRROR}" "${SUITE}" > "${rootfs}/etc/apt/sources.list"
fi

mount_root "${rootfs}"
# Prevent apt from starting daemons inside the chroot; services are enabled
# explicitly by enable-services.sh once the image is complete.
printf '#!/bin/sh\nexit 101\n' > "${rootfs}/usr/sbin/policy-rc.d"
chmod 0755 "${rootfs}/usr/sbin/policy-rc.d"

echo "Installing server/pods packages"
chroot_run "${rootfs}" apt-get update
chroot_run "${rootfs}" apt-get install -y --no-install-recommends \
	ca-certificates curl sudo python3 coreutils \
	xfce4 xfce4-session xfce4-goodies xfce4-screensaver xfconf gtk3 \
	xdg-utils xrdp xorgxrdp x11vnc xvfb x11-xserver-utils dbus-x11 \
	novnc websockify cloud-init openssh-server ufw plymouth \
	lightdm lightdm-gtk-greeter \
	grub-pc grub-efi-amd64-bin dosfstools

# hooks install the local .debs, kcd, branding, cloud-init config and services.
"${hooks}/install-kcd.sh" "${rootfs}" "${deb_arch}" "${WORK_DIR}"
"${hooks}/install-local-debs.sh" "${rootfs}" "${base_deb}" "${meta_deb}"
"${hooks}/apply-branding.sh" "${rootfs}" "${render_dir}" "${repo_root}" "${config}"
"${hooks}/configure-cloud-init.sh" "${rootfs}" "${config}" \
	"${version}" "${hostname}" "${PUBKEY_FILE}"
"${hooks}/enable-services.sh" "${rootfs}"

rm -f "${rootfs}/usr/sbin/policy-rc.d"
"${hooks}/cleanup.sh" "${rootfs}"
# Unmount before copying: cp -a must never follow a mounted /proc or /dev.
unmount_one "${rootfs}"

# --- 3. Assemble a GPT disk with BIOS + UEFI boot and copy the rootfs -------
echo "Writing GPT disk image (${SIZE})"
sfdisk "${raw}" <<EOF
label: gpt
unit: MiB
start=1, size=8, type=21686148-6449-6E6F-744E-656564454649, name=BIOS
size=512, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B, name=EFI
size=, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, name=root
EOF

loopdev="$(losetup --find --show --partscan "${raw}")"
for _ in 1 2 3 4 5; do
	[ -b "${loopdev}p3" ] && break
	sleep 0.2
done
[ -b "${loopdev}p2" ] && [ -b "${loopdev}p3" ] \
	|| die "loop partitions did not appear for ${loopdev}"

mkfs.vfat -F 32 -n CYBROIDOS-EFI "${loopdev}p2"
mkfs.ext4 -F -L cybroidos-root "${loopdev}p3"
mkdir -p "${mnt}/boot/efi"
mount "${loopdev}p3" "${mnt}"
root_mounted=1
mount "${loopdev}p2" "${mnt}/boot/efi"
efi_mounted=1
cp -a "${rootfs}/." "${mnt}/"
printf 'LABEL=cybroidos-root  /          ext4  defaults  0 1\n' > "${mnt}/etc/fstab"
printf 'LABEL=CYBROIDOS-EFI    /boot/efi  vfat  defaults  0 2\n' >> "${mnt}/etc/fstab"

mount_root "${mnt}"
echo "Installing GRUB (BIOS and UEFI) into the disk image"
chroot_run "${mnt}" grub-install --target=i386-pc --boot-directory=/boot "${loopdev}"
if ! chroot_run "${mnt}" grub-install --target=x86_64-efi \
	--efi-directory=/boot/efi --bootloader-id=cybroidos --removable; then
	note "UEFI GRUB install failed; the image still boots via BIOS/Legacy"
fi
chroot_run "${mnt}" update-grub

# --- 4. Convert + seed ------------------------------------------------------
qcow2_name="cybroid-os-${EDITION}-server-${image_arch}-${version}.qcow2"
iso_name="cybroid-os-${EDITION}-server-${image_arch}-${version}-cloud-init.iso"
qcow2="${OUT_DIR}/${qcow2_name}"
seed_iso="${OUT_DIR}/${iso_name}"

unmount_all
mounted_roots=()
efi_mounted=0
root_mounted=0
loopdev=""

echo "Converting raw disk to qcow2"
qemu-img convert -f raw -O qcow2 -o compat=1.1 "${raw}" "${qcow2}"
"${hooks}/render-seed.sh" "${config}/cloud-init" "${PUBKEY_FILE}" \
	"${version}" "${hostname}" "${seeddir}" "${seed_iso}" "${iso_tool}"

checksums="${OUT_DIR}/SHA256SUMS-${EDITION}-${image_arch}-${version}"
( cd "${OUT_DIR}" && sha256sum "${qcow2_name}" "${iso_name}" > "${checksums}" )

echo "Built artefacts (edition: ${EDITION}, version: ${version}):"
ls -lh "${qcow2}" "${seed_iso}" "${checksums}"
echo "Remember: no default password is set; log in with cybroid + your SSH key."
