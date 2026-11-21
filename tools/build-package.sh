#!/usr/bin/env bash
# Build a Cybroid OS .deb from common/packages/<name>.
#
# Renders branding from common/branding/brand.toml into the package source tree,
# keeps the changelog version in sync, and runs dpkg-buildpackage. Output lands
# in dist/.
#
# Requirements: dpkg-dev, debhelper, fakeroot, python3.
set -euo pipefail

name="${1:-cybroidos-base}"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${here}/.." && pwd)"
src="${repo_root}/common/packages/${name}"
brand="${repo_root}/common/branding/brand.toml"
release="${RELEASE:-trixie}"
out="${repo_root}/dist"

[ -d "${src}/debian" ] || { echo "error: no package '${name}' in common/packages/" >&2; exit 1; }
[ -f "${brand}" ] || { echo "error: missing ${brand}" >&2; exit 1; }

version="$(python3 -c 'import tomllib,sys; print(tomllib.load(open(sys.argv[1],"rb"))["identity"]["version"])' "${brand}")"
echo "building ${name} ${version}"

work="$(mktemp -d)"
srcdir="${work}/${name}-${version}"
mkdir -p "${srcdir}"
cp -a "${src}/debian" "${srcdir}/debian"

# Render identity + assets (paths must match debian/install).
python3 "${repo_root}/tools/render-brand.py" \
	--brand "${brand}" --release "${release}" --out "${srcdir}"
install -d "${srcdir}/usr/share/cybroidos/branding"
# /etc/issue and /etc/motd are base-files conffiles; ship them aside and place
# them in postinst.
install -d "${srcdir}/usr/share/cybroidos"
cp "${srcdir}/etc/issue" "${srcdir}/usr/share/cybroidos/issue"
cp "${srcdir}/etc/motd" "${srcdir}/usr/share/cybroidos/motd"
cp -a "${repo_root}/common/branding/logo/." "${srcdir}/usr/share/cybroidos/branding/"

# Ship the licence texts with the binary package (paths in debian/install).
install -d "${srcdir}/usr/share/doc/${name}"
cp "${repo_root}/LICENSE" "${srcdir}/usr/share/doc/${name}/LICENSE"
cp "${repo_root}/LICENSE-ASSETS" "${srcdir}/usr/share/doc/${name}/LICENSE-ASSETS"

# Keep the changelog version in sync with brand.toml.
cat > "${srcdir}/debian/changelog" <<EOF
${name} (${version}) ${release}; urgency=medium

  * Built from common/branding/brand.toml.

 -- Cybroid OS maintainers <cybroidos@cybroid.com>  $(date -R)
EOF

mkdir -p "${out}"
( cd "${srcdir}" && dpkg-buildpackage -us -uc -b )
find "${work}" -maxdepth 1 -name '*.deb' -exec mv -t "${out}" {} +
echo "built:"
ls -lh "${out}"/*.deb
