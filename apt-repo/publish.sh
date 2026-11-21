#!/usr/bin/env bash
# Publish signed Cybroid OS APT packages with reprepro.
#
# Usage: apt-repo/publish.sh <incoming-dir> [distribution]
#
# Requires: reprepro, gnupg, and a signing key available in GNUPGHOME whose ID
# is given in REPO_SIGNING_KEY. The key is never stored in this repository.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
incoming="${1:-}"
distribution="${2:-${REPO_DISTRIBUTION:-trixie}}"

if [ -z "$incoming" ] || [ ! -d "$incoming" ]; then
  printf 'usage: %s <incoming-dir> [distribution]\n' "${0##*/}" >&2
  exit 1
fi
command -v reprepro >/dev/null 2>&1 || { echo "publish: reprepro is required" >&2; exit 1; }
command -v gpg >/dev/null 2>&1 || { echo "publish: gpg is required" >&2; exit 1; }
[ -n "${REPO_SIGNING_KEY:-}" ] || { echo "publish: REPO_SIGNING_KEY is required" >&2; exit 1; }

repo_dir="${REPO_DIR:-${here}/public}"
conf_dir="${repo_dir}/conf"
mkdir -p "${conf_dir}" "${repo_dir}/incoming"

# Render the reprepro distribution config. All values can be overridden by env.
cat > "${conf_dir}/distributions" <<EOF
Origin: ${REPO_ORIGIN:-Cybroid OS}
Label: ${REPO_LABEL:-Cybroid OS}
Suite: ${distribution}
Codename: ${distribution}
Architectures: ${REPO_ARCHITECTURES:-amd64 arm64 all}
Components: ${REPO_COMPONENTS:-main}
Description: ${REPO_DESCRIPTION:-Signed Cybroid OS packages}
SignWith: ${REPO_SIGNING_KEY}
EOF

published=0
for deb in "${incoming}"/*.deb; do
  [ -e "$deb" ] || continue
  echo "publish: including $(basename "$deb")"
  reprepro -b "${repo_dir}" includedeb "${distribution}" "$deb"
  published=$((published + 1))
done

if [ "$published" -eq 0 ]; then
  echo "publish: no .deb files found in ${incoming}" >&2
  exit 1
fi

reprepro -b "${repo_dir}" export

if [ ! -f "${repo_dir}/dists/${distribution}/InRelease" ]; then
  echo "publish: InRelease was not generated — check the signing key" >&2
  exit 1
fi

echo "publish: signed repository ready at ${repo_dir}"
echo "publish: verify with: gpg --verify ${repo_dir}/dists/${distribution}/InRelease"
