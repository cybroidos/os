#!/usr/bin/env bash
# Add CIT-OS packages to the signed APT repository (ADR-0007).
#
# reprepro writes the repository to apt-repo/published/ (dists/ + pool/),
# signed with the default GnuPG key: import the CIT-OS signing key first.
# The public key is exported next to it as citos-archive-keyring.gpg.
#
# Usage: tools/publish-apt-repo.sh <deb>...
# Then serve apt-repo/published/ over HTTPS (CI publishes it to GitHub Pages).
#
# On a CIT-OS or Debian 13 machine:
#   sudo curl -fsSLo /usr/share/keyrings/citos-archive-keyring.gpg \
#     https://<repo-host>/citos-archive-keyring.gpg
#   echo "deb [signed-by=/usr/share/keyrings/citos-archive-keyring.gpg] https://<repo-host> trixie main" \
#     | sudo tee /etc/apt/sources.list.d/citos.list
#   sudo apt update && sudo apt install citos-robot
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "${here}/../apt-repo" && pwd)"

[ "$#" -gt 0 ] || { echo "usage: $0 <deb>..." >&2; exit 2; }
command -v reprepro >/dev/null || { echo "error: reprepro not installed" >&2; exit 1; }
if [ -z "$(gpg --list-secret-keys 2>/dev/null)" ]; then
	echo "error: no GnuPG secret key to sign with" >&2
	exit 1
fi

for deb in "$@"; do
	# Replace an existing version of the same package and architecture.
	reprepro -b "${repo}" includedeb trixie "${deb}"
done
reprepro -b "${repo}" export trixie
gpg --export > "${repo}/published/citos-archive-keyring.gpg"
reprepro -b "${repo}" list trixie
