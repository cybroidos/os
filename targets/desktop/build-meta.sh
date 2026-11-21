#!/usr/bin/env bash
# Generate the thin cybroidos-desktop meta-package installed into the ISO.
#
# The package exists only to express the desktop's Debian package dependencies
# in one place; it contains no branding files (those come from cybroidos-base).
# Built with dpkg-deb directly so no extra build-host tooling is required.
set -euo pipefail

usage() {
	cat <<'EOF'
usage: build-meta.sh --out DIR --version V --desktop plasma|xfce --edition LABEL [--name NAME]
EOF
}

die() { echo "error: $*" >&2; exit 1; }

out=""
version=""
desktop=""
edition=""
name="Cybroid OS"

while [ "$#" -gt 0 ]; do
	case "$1" in
		-h|--help) usage; exit 0 ;;
		--out) [ "$#" -ge 2 ] || die "--out needs a value"; out="$2"; shift 2 ;;
		--version) [ "$#" -ge 2 ] || die "--version needs a value"; version="$2"; shift 2 ;;
		--desktop) [ "$#" -ge 2 ] || die "--desktop needs a value"; desktop="$2"; shift 2 ;;
		--edition) [ "$#" -ge 2 ] || die "--edition needs a value"; edition="$2"; shift 2 ;;
		--name) [ "$#" -ge 2 ] || die "--name needs a value"; name="$2"; shift 2 ;;
		*) die "unknown option: $1" ;;
	esac
done

[ -n "${out}" ] && [ -n "${version}" ] && [ -n "${desktop}" ] && [ -n "${edition}" ] || {
	usage >&2
	exit 1
}
case "${desktop}" in
	plasma|xfce) ;;
	*) die "unsupported desktop: ${desktop}" ;;
esac
command -v dpkg-deb >/dev/null 2>&1 || die "dpkg-deb is required"

common_deps='cybroidos-base, calamares, calamares-settings-debian, plymouth, sddm, sddm-theme-debian-breeze, kdeconnect, krdp, cybroidos-control, spice-vdagent'
if [ "${desktop}" = "plasma" ]; then
	desktop_deps='kde-plasma-desktop, plasma-desktop, systemsettings, konsole, dolphin'
	summary="Cybroid OS desktop (KDE Plasma 6.3)"
else
	desktop_deps='xfce4, xfce4-goodies, xorg'
	summary="Cybroid OS Lite desktop (Xfce 4.20)"
fi

work="$(mktemp -d "${TMPDIR:-/tmp}/cybroidos-meta.XXXXXXXX")"
trap 'rm -rf "${work}"' EXIT
pkg="${work}/cybroidos-desktop"
install -d "${pkg}/DEBIAN" "${pkg}/usr/share/doc/cybroidos-desktop"

cat > "${pkg}/DEBIAN/control" <<EOF
Package: cybroidos-desktop
Version: ${version}
Section: metapackages
Priority: optional
Architecture: all
Maintainer: Cybroid OS maintainers <cybroidos@cybroid.com>
Depends: ${common_deps}, ${desktop_deps}
Homepage: https://github.com/cybroidtech/os
Description: ${summary}
 Meta-package for the Cybroid OS ${edition} desktop ISO. Pulls in the desktop,
 Calamares installer, branding base package and phone-control components so the
 image contents stay apt-managed.
EOF

cat > "${pkg}/usr/share/doc/cybroidos-desktop/copyright" <<EOF
Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Upstream-Name: Cybroid OS
Source: https://github.com/cybroidtech/os

Files: *
Copyright: 2026 Cybroid Technologies (U) Ltd
License: GPL-3+
 Build configuration for ${name}. See /usr/share/doc/cybroidos-base/LICENSE.
EOF

mkdir -p "${out}"
deb="${out}/cybroidos-desktop_${version}_all.deb"
dpkg-deb --build --root-owner-group "${pkg}" "${deb}" >/dev/null
echo "${deb}"
