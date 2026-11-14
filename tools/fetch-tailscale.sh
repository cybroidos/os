#!/usr/bin/env bash
# Fetches the Tower client: Tailscale's own Linux build (BSD-3-Clause,
# github.com/tailscale/tailscale), which Debian doesn't carry. CybroidOS
# ships it from deb.cybroid.com so every desktop can join Tower (Headscale at
# tower.cybroid.com) with no third-party package source.
#
# Checked end to end: Tailscale's repository index is verified against their
# signing key (fingerprint pinned below), the package list against the index,
# and the .deb against the package list.
#
# Usage: tools/fetch-tailscale.sh [out dir]     (default: dist/extra)
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
out="${1:-${here}/../dist/extra}"
mkdir -p "${out}"
out="$(cd "${out}" && pwd)"   # absolute: the work below happens in a temporary folder
base=https://pkgs.tailscale.com/stable/debian
suite=trixie
arch="$(dpkg --print-architecture 2>/dev/null || echo amd64)"
# Tailscale Inc. (Package repository signing key) <info@tailscale.com>
fingerprint=2596A99EAAB33821893C0A79458CA832957F5868

work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT
cd "${work}"

curl -fsSL --retry 5 --retry-all-errors --retry-delay 10 -o key.gpg "${base}/${suite}.noarmor.gpg"
got="$(gpg --show-keys --with-colons key.gpg 2>/dev/null | awk -F: '/^fpr:/{print $10; exit}')"
[ "${got}" = "${fingerprint}" ] || { echo "error: Tailscale's key changed (${got})" >&2; exit 1; }

curl -fsSL --retry 5 --retry-all-errors --retry-delay 10 -o InRelease "${base}/dists/${suite}/InRelease"
gpgv --keyring ./key.gpg InRelease 2>/dev/null || { echo "error: bad signature on Tailscale's index" >&2; exit 1; }

curl -fsSL --retry 5 --retry-all-errors --retry-delay 10 -o Packages "${base}/dists/${suite}/main/binary-${arch}/Packages"
want="$(awk -v p="main/binary-${arch}/Packages" '/^SHA256:/{s=1;next} /^[A-Z]/{s=0} s&&$3==p{print $1}' InRelease)"
echo "${want}  Packages" | sha256sum -c --quiet

read -r version file sum < <(awk '/^Package: /{p=($2=="tailscale")} p&&/^Version:/{v=$2} p&&/^Filename:/{f=$2} p&&/^SHA256:/{print v, f, $2}' Packages | sort -V | tail -1)
deb="$(basename "${file}")"
curl -fsSL --retry 5 --retry-all-errors --retry-delay 10 -o "${deb}" "${base}/${file}"
echo "${sum}  ${deb}" | sha256sum -c --quiet

mkdir -p "${out}"
cp "${deb}" "${out}/"
echo "tailscale ${version} (${arch}), verified"
