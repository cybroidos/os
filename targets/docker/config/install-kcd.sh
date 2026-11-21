#!/bin/sh
# Install kcd (headless KDE Connect, ADR-0004/0005) from the upstream release.
# kcd is not packaged in Debian Trixie, so the amd64/arm64 .deb assets are
# pinned by SHA-256 from the upstream v2.0.1 release. No secrets are involved.
set -eu

KCD_VERSION="2.0.1"

case "$(dpkg --print-architecture)" in
	amd64)
		kcd_arch="x86_64"
		kcd_sha="309b6b2787bc61d6857a5a90086bf83f1c48fc2a20cc3826e5a070c0066dabc5"
		;;
	arm64)
		kcd_arch="aarch64"
		kcd_sha="cb517ff4167081003c4addb3db4bbed3c4a1faae72c77084ab2357c7c0bc84fc"
		;;
	*)
		echo "error: kcd has no pinned asset for $(dpkg --print-architecture)" >&2
		exit 1
		;;
esac

url="https://github.com/bethropolis/kcd/releases/download/v${KCD_VERSION}/kcd_${KCD_VERSION}_${kcd_arch}.deb"
tmp="$(mktemp)"
trap 'rm -f "${tmp}"' EXIT INT TERM

curl -fsSL "${url}" -o "${tmp}"
printf '%s  %s\n' "${kcd_sha}" "${tmp}" | sha256sum -c -
dpkg -i "${tmp}"

command -v kcd >/dev/null
echo "installed kcd ${KCD_VERSION} (${kcd_arch})"
