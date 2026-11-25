#!/usr/bin/env bash
# Fetches Docker Engine as Docker itself publishes it (docker-ce, its CLI,
# containerd, Buildx and the Compose plugin; Apache-2.0, docs.docker.com):
# the version Docker's documentation, courses and employers assume. Debian's
# own docker.io lags it by several releases. CybroidOS ships it from
# deb.cybroid.com, so installed computers get its updates like any other
# package.
#
# Checked end to end, as tools/fetch-onlyoffice.sh: Docker's repository index
# against their signing key (fingerprint pinned below), the package list
# against the index, and each .deb against the package list.
#
# Usage: tools/fetch-docker.sh [out dir]     (default: dist/extra)
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
out="${1:-${here}/../dist/extra}"
mkdir -p "${out}"
out="$(cd "${out}" && pwd)"
base=https://download.docker.com/linux/debian
suite=trixie
arch="$(dpkg --print-architecture 2>/dev/null || echo amd64)"
packages="docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"
# Docker Release (CE deb) <docker@docker.com>
fingerprint=9DC858229FC7DD38854AE2D88D81803C0EBFCD88
get() { curl -fsSL --http1.1 --retry 5 --retry-all-errors --retry-delay 15 "$@"; }

work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT
cd "${work}"

get -o key.asc "${base}/gpg"
gpg --dearmor < key.asc > key.gpg
got="$(gpg --show-keys --with-colons key.gpg 2>/dev/null | awk -F: '/^fpr:/{print $10; exit}')"
[ "${got}" = "${fingerprint}" ] || { echo "error: Docker's key changed (${got})" >&2; exit 1; }

get -o InRelease "${base}/dists/${suite}/InRelease"
gpgv --keyring ./key.gpg InRelease 2>/dev/null || { echo "error: bad signature on Docker's index" >&2; exit 1; }

get -o Packages "${base}/dists/${suite}/stable/binary-${arch}/Packages"
want="$(awk -v p="stable/binary-${arch}/Packages" '/^SHA256:/{s=1;next} /^[A-Z]/{s=0} s&&$3==p{print $1}' InRelease)"
echo "${want}  Packages" | sha256sum -c --quiet

for pkg in ${packages}; do
	read -r version file sum < <(awk -v want="${pkg}" '/^Package: /{p=($2==want)} p&&/^Version:/{v=$2} p&&/^Filename:/{f=$2} p&&/^SHA256:/{print v, f, $2}' Packages | sort -V | tail -1)
	[ -n "${file:-}" ] || { echo "error: ${pkg} isn't in Docker's ${suite} index" >&2; exit 1; }
	deb="$(basename "${file}")"
	get -o "${deb}" "${base}/${file}"
	echo "${sum}  ${deb}" | sha256sum -c --quiet
	rm -f "${out}/${pkg}"_*.deb
	cp "${deb}" "${out}/"
	echo "${pkg} ${version} (${arch}), verified"
done
