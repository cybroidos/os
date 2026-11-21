#!/usr/bin/env bash
# Build an installable Cybroid OS desktop ISO with Debian live-build.
#
# Produces a Debian 13 "Trixie" iso-hybrid image containing Calamares, KDE Plasma
# (default) or the Xfce 4.20 "Lite" desktop, branded from common/branding/brand.toml
# and the locally built cybroidos-base .deb. See targets/desktop/README.md.
#
# Env: ARCH (amd64|arm64), DESKTOP (plasma|xfce), EDITION (label, e.g. core or
# core-lite), BASE_EDITION (edition config name, e.g. core), OUT_DIR,
# BASE_DEB, CONTROL_DEB, KEEP_WORK (1 keeps the temporary build tree),
# RELEASE (default trixie).
set -euo pipefail

usage() {
	cat <<'EOF'
usage: targets/desktop/build.sh

Build a Cybroid OS desktop ISO. Options are environment variables:

  ARCH=amd64|arm64       target architecture (default: amd64)
  DESKTOP=plasma|xfce    desktop variant (default: plasma)
  EDITION=core           release label; xfce appends -lite by default
  BASE_EDITION=core      edition config to load from editions/
  OUT_DIR=DIR            artifact directory (default: dist/desktop)
  BASE_DEB=FILE          local cybroidos-base .deb (default: dist/*.deb)
  CONTROL_DEB=FILE       optional local cybroidos-control .deb
  KEEP_WORK=1            keep the temporary live-build tree
EOF
}

die() { echo "error: $*" >&2; exit 1; }
note() { echo "note: $*" >&2; }

[ "${1:-}" != "--help" ] || { usage; exit 0; }
[ "$#" -eq 0 ] || die "unexpected argument: $1 (use environment variables)"

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${here}/../.." && pwd)"
brand="${repo_root}/common/branding/brand.toml"
release="${RELEASE:-trixie}"

ARCH="${ARCH:-amd64}"
DESKTOP="${DESKTOP:-plasma}"
case "${ARCH}" in
	amd64|arm64) ;;
	*) die "unsupported ARCH '${ARCH}' (expected amd64 or arm64)" ;;
esac
case "${DESKTOP}" in
	plasma|xfce) ;;
	*) die "unsupported DESKTOP '${DESKTOP}' (expected plasma or xfce)" ;;
esac

# EDITION is the release label used in the artifact name. BASE_EDITION selects
# the edition config. When only DESKTOP=xfce is given, "-lite" is appended so
# the two matrix builds cannot overwrite each other (ADR-0003).
edition_explicit=0
[ -z "${EDITION:-}" ] || edition_explicit=1
EDITION="${EDITION:-${BASE_EDITION:-core}}"
if [ "${DESKTOP}" = "xfce" ] && [ "${edition_explicit}" -eq 0 ]; then
	EDITION="${EDITION}-lite"
fi
base_edition="${BASE_EDITION:-${EDITION%-lite}}"
edition_config="${repo_root}/editions/${base_edition}/config"
[ -f "${edition_config}" ] || die "unknown edition '${base_edition}' (expected ${edition_config})"

# Defaults before sourcing: the edition config is trusted, versioned shell.
EDITION_NAME="${EDITION_NAME:-Cybroid OS}"
ENABLE_KIOSK_MODE="${ENABLE_KIOSK_MODE:-0}"
# shellcheck disable=SC1090  # edition config is a trusted, versioned file
. "${edition_config}"
kiosk_enabled="false"
[ "${ENABLE_KIOSK_MODE}" = "1" ] && kiosk_enabled="true"

[ -f "${brand}" ] || die "missing ${brand}"
[ -f "${repo_root}/tools/render-brand.py" ] || die "missing tools/render-brand.py"
[ -f "${here}/config/auto/config" ] || die "missing config/auto/config"
[ "$(id -u)" -eq 0 ] || die "live-build must run as root (CI uses a privileged Debian 13 container)"

for cmd in lb debootstrap xorriso python3 dpkg-deb install sed grep find; do
	command -v "${cmd}" >/dev/null 2>&1 || die "required tool not found: ${cmd}"
done

# Read brand values once. shlex.quote keeps the generated fragment safe to source.
work="$(mktemp -d "${TMPDIR:-/tmp}/cybroidos-desktop.XXXXXXXX")"
cleanup() {
	if [ "${KEEP_WORK:-0}" = "1" ]; then
		echo "note: kept live-build work tree at ${work}" >&2
	else
		rm -rf "${work}"
	fi
}
trap cleanup EXIT

python3 - "${brand}" > "${work}/brand.env" <<'PY'
import shlex
import sys
import tomllib

with open(sys.argv[1], "rb") as fh:
    brand = tomllib.load(fh)
ident = brand["identity"]
colors = brand["colors"]
values = {
    "product_name": ident["name"],
    "product_pretty": ident["pretty_name"],
    "vendor": ident["vendor"],
    "vendor_short": ident["vendor_short"],
    "version": ident["version"],
    "support_url": ident["support_url"],
    "primary": colors["primary"],
    "primary_deep": colors["primary_deep"],
    "accent": colors["accent"],
    "accent_alt": colors["accent_alt"],
    "background": colors["background"],
    "foreground": colors["foreground"],
}
for key, value in values.items():
    print(f"{key}={shlex.quote(str(value))}")
PY
# shellcheck disable=SC1091  # generated in this script
. "${work}/brand.env"

out_dir="${OUT_DIR:-${repo_root}/dist/desktop}"
mkdir -p "${out_dir}"

# Locate the locally built shared branding package. Building it is deliberately
# left to tools/build-package.sh so the brand source stays single-sourced.
base_deb="${BASE_DEB:-}"
if [ -z "${base_deb}" ]; then
	base_deb="$(find "${repo_root}/dist" -maxdepth 1 -name 'cybroidos-base_*.deb' -print 2>/dev/null | sort | tail -n 1 || true)"
fi
[ -n "${base_deb}" ] && [ -f "${base_deb}" ] || die "no cybroidos-base .deb; run: tools/build-package.sh cybroidos-base"
control_deb="${CONTROL_DEB:-}"
if [ -z "${control_deb}" ]; then
	control_deb="$(find "${repo_root}/dist" -maxdepth 1 -name 'cybroidos-control_*.deb' -print 2>/dev/null | sort | tail -n 1 || true)"
fi

# --- Assemble a live-build tree in a throwaway directory ---------------------
install -d "${work}/auto"
install -d "${work}/config/hooks/live"
install -d "${work}/config/package-lists"
install -d "${work}/config/includes.chroot"
# Note: includes.chroot/root is where build inputs are staged for the chroot
# hooks; hooks remove them before the image is written.
stage="${work}/config/includes.chroot/root/cybroidos-build"
install -d "${stage}/debs"

cp "${here}/config/auto/config" "${work}/auto/config"
chmod 0755 "${work}/auto/config"
cp -a "${here}/config/includes.chroot/." "${work}/config/includes.chroot/"
cp -a "${here}/hooks/." "${work}/config/hooks/live/"
chmod 0755 "${work}/config/hooks/live/"*.hook.chroot

# Render the canonical identity/banners/Plymouth theme from brand.toml.
python3 "${repo_root}/tools/render-brand.py" \
	--brand "${brand}" --release "${release}" --out "${stage}/brand" >/dev/null
for required in \
	"${stage}/brand/etc/motd" \
	"${stage}/brand/etc/issue" \
	"${stage}/brand/usr/lib/os-release" \
	"${stage}/brand/usr/share/plymouth/themes/cybroidos/cybroidos.plymouth" \
	"${stage}/brand/usr/share/plymouth/themes/cybroidos/cybroidos.script"; do
	[ -f "${required}" ] || die "branding render did not produce ${required}"
done

install -d "${stage}/assets"
cp -a "${repo_root}/common/branding/logo/." "${stage}/assets/"
[ -f "${stage}/assets/cybroid-logo.png" ] || die "missing brand logo: cybroid-logo.png"

# Substitute build-time values in the static overlays and asset templates.
render_template() {
	local src="$1" dst="$2"
	sed \
		-e "s|@PRODUCT_NAME@|${product_name}|g" \
		-e "s|@PRODUCT_PRETTY@|${product_pretty}|g" \
		-e "s|@VERSION@|${version}|g" \
		-e "s|@VENDOR@|${vendor}|g" \
		-e "s|@VENDOR_SHORT@|${vendor_short}|g" \
		-e "s|@SUPPORT_URL@|${support_url}|g" \
		-e "s|@EDITION@|${EDITION}|g" \
		-e "s|@BASE_EDITION@|${base_edition}|g" \
		-e "s|@EDITION_NAME@|${EDITION_NAME}|g" \
		-e "s|@DESKTOP@|${DESKTOP}|g" \
		-e "s|@ARCH@|${ARCH}|g" \
		-e "s|@KIOSK_ENABLED@|${kiosk_enabled}|g" \
		-e "s|@PRIMARY@|${primary}|g" \
		-e "s|@PRIMARY_DEEP@|${primary_deep}|g" \
		-e "s|@ACCENT@|${accent}|g" \
		-e "s|@ACCENT_ALT@|${accent_alt}|g" \
		-e "s|@BACKGROUND@|${background}|g" \
		-e "s|@FOREGROUND@|${foreground}|g" \
		"${src}" > "${dst}"
}

for f in \
	etc/cybroidos/desktop.conf \
	etc/xdg/cybroidos-kiosk.conf; do
	render_template \
		"${here}/config/includes.chroot/${f}" \
		"${work}/config/includes.chroot/${f}"
done
install -d "${stage}/templates"
for f in \
	wallpaper.svg \
	sddm-theme.conf \
	grub-theme.txt \
	calamares-branding.desc \
	plasma-metadata.desktop \
	plasma-kdeglobals \
	plasma-appletsrc \
	plymouthd.conf \
	grub-cybroidos.cfg; do
	render_template "${here}/config/assets/${f}" "${stage}/templates/${f}"
done

# Machine-readable identity used by the chroot hooks (no secrets, no eval of
# untrusted input: values are shlex-quoted above).
{
	printf "product_name=%q\n" "${product_name}"
	printf "product_pretty=%q\n" "${product_pretty}"
	printf "version=%q\n" "${version}"
	printf "vendor=%q\n" "${vendor}"
	printf "vendor_short=%q\n" "${vendor_short}"
	printf "id=cybroidos\n"
	printf "hostname=cybroid\n"
	printf "edition=%q\n" "${EDITION}"
	printf "base_edition=%q\n" "${base_edition}"
	printf "desktop=%q\n" "${DESKTOP}"
	printf "kiosk_enabled=%q\n" "${kiosk_enabled}"
	printf "arch=%q\n" "${ARCH}"
	printf "support_url=%q\n" "${support_url}"
	printf "release=%q\n" "${release}"
} > "${stage}/identity.env"

# Build the local meta-package. It is a thin Depends-only .deb so the desktop
# package set is apt-managed, not embedded in a custom package tree.
"${here}/build-meta.sh" \
	--out "${stage}/debs" \
	--version "${version}" \
	--desktop "${DESKTOP}" \
	--edition "${EDITION}" \
	--name "${EDITION_NAME}"
cp "${base_deb}" "${stage}/debs/"
if [ -n "${control_deb}" ] && [ -f "${control_deb}" ]; then
	cp "${control_deb}" "${stage}/debs/"
else
	note "no local cybroidos-control .deb; the meta-package will request it from apt"
fi

# Package lists: common desktop tooling plus the selected desktop.
{
	printf '# Generated by targets/desktop/build.sh — do not edit.\n'
	cat "${here}/config/package-lists/common.list.chroot"
	if [ "${DESKTOP}" = "plasma" ]; then
		cat "${here}/config/package-lists/plasma.list.chroot"
	else
		cat "${here}/config/package-lists/xfce.list.chroot"
	fi
} > "${work}/config/package-lists/cybroidos.list.chroot"

# auto/config reads these exported values; it is copied verbatim from the repo.
export CYBROIDOS_ARCH="${ARCH}"
export CYBROIDOS_EDITION="${EDITION}"
export CYBROIDOS_VERSION="${version}"
export CYBROIDOS_PRODUCT_NAME="${product_name}"
export CYBROIDOS_VENDOR="${vendor}"
export CYBROIDOS_RELEASE="${release}"

echo "Building ${product_name} ${version} (edition=${EDITION}, desktop=${DESKTOP}, arch=${ARCH})"
( cd "${work}" && lb config && lb build )

iso="$(find "${work}" -maxdepth 1 -type f \( -name '*.hybrid.iso' -o -name '*.iso' \) -print | head -n 1)"
[ -n "${iso}" ] && [ -f "${iso}" ] || die "live-build did not produce an ISO"

iso_name="cybroid-os-${EDITION}-desktop-${ARCH}-${version}.iso"
final="${out_dir}/${iso_name}"
install -m 0644 "${iso}" "${final}"
sha256sum "${final}" > "${final}.sha256"
echo "ISO: ${final}"
echo "checksum: ${final}.sha256"
