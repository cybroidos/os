#!/usr/bin/env bash
# Fetches the office suite: ONLYOFFICE Desktop Editors (AGPL-3.0,
# github.com/ONLYOFFICE/DesktopEditors), closest to Microsoft Office in look
# and in how faithfully it keeps .docx, .xlsx and .pptx. Debian doesn't carry
# it; CybroidOS ships it from deb.cybroid.com, so installed computers get its
# updates like any other package.
#
# Checked end to end, as tools/fetch-tailscale.sh: ONLYOFFICE's repository
# index against their signing key (fingerprint pinned below), the package
# list against the index, and the .deb against the package list.
#
# Usage: tools/fetch-onlyoffice.sh [out dir]     (default: dist/extra)
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
out="${1:-${here}/../dist/extra}"
mkdir -p "${out}"
out="$(cd "${out}" && pwd)"
base=https://download.onlyoffice.com/repo/debian
suite=squeeze   # ONLYOFFICE's one suite, for every Debian release
arch="$(dpkg --print-architecture 2>/dev/null || echo amd64)"
# Ascensio System Limited (ONLYOFFICE) <support@onlyoffice.com>
fingerprint=E09CA29F6E178040EF22B4098320CA65CB2DE8E5
get() { curl -fsSL --http1.1 --retry 5 --retry-all-errors --retry-delay 15 "$@"; }

work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT
cd "${work}"

get -o key.asc https://download.onlyoffice.com/GPG-KEY-ONLYOFFICE
gpg --dearmor < key.asc > key.gpg
got="$(gpg --show-keys --with-colons key.gpg 2>/dev/null | awk -F: '/^fpr:/{print $10; exit}')"
[ "${got}" = "${fingerprint}" ] || { echo "error: ONLYOFFICE's key changed (${got})" >&2; exit 1; }

get -o InRelease "${base}/dists/${suite}/InRelease"
gpgv --keyring ./key.gpg InRelease 2>/dev/null || { echo "error: bad signature on ONLYOFFICE's index" >&2; exit 1; }

get -o Packages "${base}/dists/${suite}/main/binary-${arch}/Packages"
want="$(awk -v p="main/binary-${arch}/Packages" '/^SHA256:/{s=1;next} /^[A-Z]/{s=0} s&&$3==p{print $1}' InRelease)"
echo "${want}  Packages" | sha256sum -c --quiet

read -r version file sum < <(awk '/^Package: /{p=($2=="onlyoffice-desktopeditors")} p&&/^Version:/{v=$2} p&&/^Filename:/{f=$2} p&&/^SHA256:/{print v, f, $2}' Packages | sort -V | tail -1)
deb="onlyoffice-desktopeditors_${version}_${arch}.deb"
get -o "${deb}" "${base}/${file}"
echo "${sum}  ${deb}" | sha256sum -c --quiet

rm -f "${out}"/onlyoffice-desktopeditors_*.deb
cp "${deb}" "${out}/"
echo "onlyoffice-desktopeditors ${version} (${arch}), verified"
