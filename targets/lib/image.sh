# shellcheck shell=bash
# Shared steps for building CybroidOS images from a Debian 13 root filesystem
# (sourced by targets/server/build.sh and targets/container/build.sh).

repo="${repo:?}"
VERSION="$(python3 -c 'import tomllib,sys; print(tomllib.load(open(sys.argv[1],"rb"))["identity"]["version"])' "${repo}/common/branding/brand.toml")"

die() { echo "error: $*" >&2; exit 1; }
need() { for c in "$@"; do command -v "$c" >/dev/null || die "$c not found"; done; }

# A working folder for building an image, on disk: /tmp is often a small
# tmpfs in memory (7.8 GB on a 16 GB laptop), and a desktop chroot, its
# squashfs and the ISO take far more. Under /var/tmp unless
# CYBROID_BUILD_TMP says otherwise; stops early when there's less free
# than the build needs.
#   work="$(build_dir 30)"   (GB needed)
build_dir() {
	local base="${CYBROID_BUILD_TMP:-/var/tmp}" need_gb="${1:-10}" free_gb
	mkdir -p "${base}"
	free_gb=$(( $(df -Pk "${base}" | awk 'NR==2{print $4}') / 1048576 ))
	(( free_gb >= need_gb )) || die "${base} has ${free_gb} GB free; this build needs about ${need_gb} GB (set CYBROID_BUILD_TMP to a bigger disk)"
	mktemp -d -p "${base}" cybroid-build.XXXXXX
}

# Build the named CybroidOS packages into dist/ unless they're there already.
build_debs() {
	local p
	for p in "$@"; do
		[ -f "${repo}/dist/${p}_${VERSION}_all.deb" ] || OUT="${repo}/dist" "${repo}/tools/build-package.sh" "$p"
	done
}

mount_chroot() { # root
	local r="$1" d
	for d in dev dev/pts proc sys; do
		mkdir -p "${r}/${d}"
		mount --bind "/${d}" "${r}/${d}"
	done
	# Name resolution for apt, whatever the image's own resolv.conf is.
	if [ -e "${r}/etc/resolv.conf" ] || [ -L "${r}/etc/resolv.conf" ]; then
		mv "${r}/etc/resolv.conf" "${r}/etc/resolv.conf.cybroid-build"
	fi
	cp /etc/resolv.conf "${r}/etc/resolv.conf"
}

unmount_chroot() { # root
	local r="$1" d
	[ -d "${r}" ] || return 0
	if [ -e "${r}/etc/resolv.conf.cybroid-build" ] || [ -L "${r}/etc/resolv.conf.cybroid-build" ]; then
		rm -f "${r}/etc/resolv.conf"
		mv "${r}/etc/resolv.conf.cybroid-build" "${r}/etc/resolv.conf"
	fi
	# Programs a package started inside (an agent, a daemon) keep the image
	# busy, and the disk can't be unmounted ("target is busy"): stopped.
	local real pid
	real="$(readlink -f "${r}")"
	for pid in /proc/[0-9]*; do
		[ "$(readlink "${pid}/root" 2>/dev/null)" = "${real}" ] && kill -9 "${pid#/proc/}" 2>/dev/null
	done
	sleep 1
	for d in sys proc dev/pts dev; do
		mountpoint -q "${r}/${d}" && umount -l "${r}/${d}"
	done
	return 0
}

# Install the CybroidOS packages in CYBROID_PACKAGES (cybroid-base unless set) and
# extra Debian packages, brand the system as the given os-release variant
# (server, desktop, container) and leave it clean for cloning: no machine
# id, no SSH host keys, no apt lists.
install_cybroid() { # root variant extra-packages...
	local r="$1" variant="$2" p
	shift 2
	install -d "${r}/tmp/cybroid-debs"
	for p in ${CYBROID_PACKAGES:-cybroid-base}; do
		cp "${repo}/dist/${p}_${VERSION}_all.deb" "${r}/tmp/cybroid-debs/"
	done
	# Other packages built for the image (EXTRA_DEBS: a folder of .debs, such
	# as the rounded-corners effect).
	if [ -n "${EXTRA_DEBS:-}" ] && ls "${EXTRA_DEBS}"/*.deb >/dev/null 2>&1; then
		cp "${EXTRA_DEBS}"/*.deb "${r}/tmp/cybroid-debs/"
	fi
	chroot "${r}" /usr/bin/env DEBIAN_FRONTEND=noninteractive LC_ALL=C.UTF-8 sh -ec "
		apt-get update -q
		apt-get install -y -q --no-install-recommends /tmp/cybroid-debs/*.deb $*
		apt-get clean
	"
	rm -rf "${r}/tmp/cybroid-debs" "${r}/var/lib/apt/lists/"*

	# os-release with the variant (cybroid-base ships the plain identity).
	local overlay
	overlay="$(mktemp -d)"
	python3 "${repo}/tools/render-brand.py" --target "${variant}" --only identity --out "${overlay}" >/dev/null
	install -m 0644 "${overlay}/usr/lib/os-release" "${r}/usr/lib/os-release"
	rm -rf "${overlay}"

	# New accounts get no "Debian" full name from cloud-init (desktops show it).
	[ -f "${r}/etc/cloud/cloud.cfg" ] && sed -i '/^[[:space:]]*gecos:/d' "${r}/etc/cloud/cloud.cfg"

	echo cybroid > "${r}/etc/hostname"
	: > "${r}/etc/machine-id"
	rm -f "${r}/var/lib/dbus/machine-id" "${r}/etc/ssh/ssh_host_"*
}
