#!/usr/bin/env bash
# Build CybroidOS .deb packages from common/packages/<name>/ (ADR-0007).
#
# A package directory holds:
#   control          DEBIAN/control; @VERSION@ is replaced with the CybroidOS
#                    version from common/branding/brand.toml
#   files/           static files at their install paths (optional)
#   prepare          executable that stages generated files (optional):
#                    prepare <package-root> <repo-root>
#   preinst postinst prerm postrm    maintainer scripts (optional)
#   triggers         DEBIAN/triggers (optional), e.g. interest-noawait <dir>
#
# Files under etc/ become conffiles. Packages are built with plain dpkg-deb,
# so arm64 packages of prebuilt binaries build on any host with no
# cross-compiler.
#
# Usage: tools/build-package.sh <name>...      build the named packages
#        tools/build-package.sh --all          every package that can build here
# Env:   OUT (dist/), VERSION (brand.toml), and inputs some packages need:
#        KIOSK_BUNDLE (cybroid-kiosk-app: a flutterpi_tool release bundle).
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${here}/.." && pwd)"
pkgs_dir="${repo_root}/common/packages"
out="${OUT:-${repo_root}/dist}"
brand="${repo_root}/common/branding/brand.toml"

die() { echo "error: $*" >&2; exit 1; }
command -v dpkg-deb >/dev/null || die "dpkg-deb not found"

version="${VERSION:-$(python3 -c 'import tomllib,sys; print(tomllib.load(open(sys.argv[1],"rb"))["identity"]["version"])' "${brand}")}"

build_one() {
	local name="$1"
	local src="${pkgs_dir}/${name}"
	[ -f "${src}/control" ] || die "no package '${name}' (missing ${src}/control)"

	local work root
	work="$(mktemp -d)"
	root="${work}/${name}"
	mkdir -p "${root}"
	if [ -d "${src}/files" ]; then
		cp -a "${src}/files/." "${root}/"
	fi
	if [ -x "${src}/prepare" ]; then
		"${src}/prepare" "${root}" "${repo_root}"
	fi
	find "${root}" -name '__pycache__' -type d -prune -exec rm -rf {} +

	# Debian-style docs: copyright and a changelog.
	local doc="${root}/usr/share/doc/${name}"
	install -d "${doc}"
	install -m 0644 "${pkgs_dir}/copyright" "${doc}/copyright"
	printf '%s (%s) trixie; urgency=medium\n\n  * Built from the cit-os repository.\n\n -- CybroidOS maintainers <citos@cybroid.com>  %s\n' \
		"${name}" "${version}" "$(date -R)" | gzip -9n > "${doc}/changelog.gz"

	# Normalise permissions: the source tree's umask must not leak in.
	find "${root}" -type d -exec chmod 0755 {} +
	find "${root}" -type f -exec chmod u+rw,go+r,go-w {} +

	install -d "${root}/DEBIAN"
	local size
	size="$(du -sk --exclude=DEBIAN "${root}" | cut -f1)"
	sed -e "s/@VERSION@/${version}/g" "${src}/control" > "${root}/DEBIAN/control"
	printf 'Installed-Size: %s\n' "${size}" >> "${root}/DEBIAN/control"

	for script in preinst postinst prerm postrm; do
		if [ -f "${src}/${script}" ]; then
			install -m 0755 "${src}/${script}" "${root}/DEBIAN/${script}"
		fi
	done
	if [ -f "${src}/triggers" ]; then
		install -m 0644 "${src}/triggers" "${root}/DEBIAN/triggers"
	fi
	if [ -d "${root}/etc" ]; then
		(cd "${root}" && find etc -type f | sort | sed 's|^|/|') > "${root}/DEBIAN/conffiles"
		[ -s "${root}/DEBIAN/conffiles" ] || rm "${root}/DEBIAN/conffiles"
	fi
	(cd "${root}" && find . -path ./DEBIAN -prune -o -type f -print0 | sort -z \
		| xargs -0 -r md5sum | sed 's| \./| |') > "${root}/DEBIAN/md5sums"

	local arch deb
	arch="$(sed -n 's/^Architecture: *//p' "${root}/DEBIAN/control")"
	deb="${out}/${name}_${version}_${arch}.deb"
	mkdir -p "${out}"
	dpkg-deb --root-owner-group -Zxz --build "${root}" "${deb}" >/dev/null
	rm -rf "${work}"
	echo "built ${deb#"${repo_root}"/}"
}

# Transitional packages: CybroidOS was CIT-OS until 0.1.2, and its packages
# were citos-*. Each old name becomes an empty package that depends on the
# new one, so "apt upgrade" moves an installed system across; the new
# packages Replace and Break the old ones (their control files).
build_transitional() {
	local name="$1" old="${1/cybroid/citos}"
	[ "${old}" != "${name}" ] || return 0
	local work root arch
	work="$(mktemp -d)"
	root="${work}/${old}"
	install -d "${root}/DEBIAN" "${root}/usr/share/doc/${old}"
	install -m 0644 "${pkgs_dir}/copyright" "${root}/usr/share/doc/${old}/copyright"
	arch="$(sed -n 's/^Architecture: *//p' "${pkgs_dir}/${name}/control")"
	{
		echo "Package: ${old}"
		echo "Version: ${version}"
		echo "Architecture: ${arch}"
		echo "Maintainer: CybroidOS maintainers <citos@cybroid.com>"
		echo "Section: oldlibs"
		echo "Priority: optional"
		echo "Depends: ${name} (>= ${version})"
		echo "Description: transitional package: ${old} is now ${name}"
		echo " CIT-OS is now CybroidOS. This empty package moves an installed system to"
		echo " ${name}; it can be removed afterwards."
	} > "${root}/DEBIAN/control"
	mkdir -p "${out}"
	dpkg-deb --root-owner-group -Zxz --build "${root}" "${out}/${old}_${version}_${arch}.deb" >/dev/null
	rm -rf "${work}"
	echo "built ${old}_${version}_${arch}.deb (transitional)"
}

# Packages whose inputs come from another build (the Flutter bundle).
needs_input() {
	case "$1" in
	cybroid-kiosk-app) [ -n "${KIOSK_BUNDLE:-}" ] ;;
	*) true ;;
	esac
}

[ "$#" -gt 0 ] || die "usage: $0 <package>... | --all"
if [ "$1" = "--all" ]; then
	for dir in "${pkgs_dir}"/*/; do
		name="$(basename "${dir}")"
		[ -f "${dir}/control" ] || continue
		if needs_input "${name}"; then
			build_one "${name}"
			build_transitional "${name}"
		else
			echo "skip ${name} (input not provided)"
		fi
	done
else
	for name in "$@"; do
		build_one "${name}"
	done
fi
