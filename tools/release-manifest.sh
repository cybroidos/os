#!/usr/bin/env bash
# Generate a release manifest for CybroidOS artifacts.
#
# Usage: tools/release-manifest.sh [options] [artifact-dir] [output-file]
#   --edition NAME        edition label (default: $EDITION or desktop)
#   --packages-file FILE  file whose lines become the per-image SBOM section
#   --sign                produce a detached armoured signature using GPG_KEY
#
# The token in GPG_KEY is a key ID; it is never written into the manifest.
set -euo pipefail

usage() {
  printf 'usage: %s [--edition NAME] [--packages-file FILE] [--sign] [artifact-dir] [output-file]\n' "${0##*/}" >&2
}

edition="${EDITION:-desktop}"
packages_file=""
sign=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --edition)
      [ "$#" -ge 2 ] || { echo "release-manifest: --edition needs a value" >&2; exit 1; }
      edition="$2"; shift 2 ;;
    --packages-file)
      [ "$#" -ge 2 ] || { echo "release-manifest: --packages-file needs a path" >&2; exit 1; }
      packages_file="$2"; shift 2 ;;
    --sign) sign=1; shift ;;
    --) shift; break ;;
    -*) echo "release-manifest: unknown option $1" >&2; usage; exit 1 ;;
    *) break ;;
  esac
done

artifact_dir="${1:-out}"
output_file="${2:-}"

if [ ! -d "$artifact_dir" ]; then
  printf 'release-manifest: artifact directory not found: %s\n' "$artifact_dir" >&2
  exit 1
fi
if [ -n "$packages_file" ] && [ ! -f "$packages_file" ]; then
  printf 'release-manifest: packages file not found: %s\n' "$packages_file" >&2
  exit 1
fi
if [ "$sign" -eq 1 ] && [ -z "${GPG_KEY:-}" ]; then
  echo "release-manifest: --sign requires GPG_KEY (a key ID)" >&2
  exit 1
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
commit="$(git -C "$repo_root" rev-parse HEAD 2>/dev/null || printf 'unknown')"
branch="$(git -C "$repo_root" branch --show-current 2>/dev/null || printf 'unknown')"
generated="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
version="$(python3 -c '
import pathlib, sys, tomllib
data = tomllib.loads(pathlib.Path(sys.argv[1]).read_text())
print(data.get("identity", {}).get("version", "unknown"))
' "$repo_root/common/branding/brand.toml" 2>/dev/null || printf 'unknown')"

manifest_tmp="$(mktemp)"
artifact_tmp="$(mktemp)"
trap 'rm -f "$manifest_tmp" "$artifact_tmp"' EXIT

find "$artifact_dir" -maxdepth 2 -type f \
  \( -name '*.img' -o -name '*.img.xz' -o -name '*.iso' -o -name '*.qcow2' \
     -o -name '*.deb' -o -name '*.tar.gz' -o -name '*.sha256' \) \
  -print0 > "$artifact_tmp" 2>/dev/null || true

{
  printf '# CybroidOS release manifest\n\n'
  printf 'generated_utc: %s\n' "$generated"
  printf 'git_commit: %s\n' "$commit"
  printf 'git_branch: %s\n' "$branch"
  printf 'edition: %s\n' "$edition"
  printf 'brand_version: %s\n\n' "$version"

  printf '## Artifacts (sha256)\n\n'
  artifact_count=0
  while IFS= read -r -d '' artifact; do
    artifact_count=$((artifact_count + 1))
    checksum="$(sha256sum "$artifact" | awk '{print $1}')"
    printf '%s  %s\n' "$checksum" "$(basename "$artifact")"
  done < "$artifact_tmp"
  if [ "$artifact_count" -eq 0 ]; then
    printf '(no release artifacts found in %s)\n' "$artifact_dir"
  fi

  printf '\n## Image SBOM (installed packages)\n\n'
  if [ -n "$packages_file" ]; then
    sed 's/^/- /' "$packages_file"
  else
    printf '(no packages file supplied; pass --packages-file)\n'
  fi

  printf '\n## Licence set\n\n'
  printf -- '- LICENSE (GPL-3.0-or-later)\n'
  printf -- '- LICENSE-ASSETS (CC BY-NC 4.0)\n'
  printf -- '- NOTICE.md\n'
  printf -- '- docs/PROPRIETARY-COMPONENTS.md\n'
} > "$manifest_tmp"

if [ -n "$output_file" ]; then
  mkdir -p "$(dirname "$output_file")"
  cp "$manifest_tmp" "$output_file"
  printf 'release-manifest: wrote %s\n' "$output_file" >&2
  if [ "$sign" -eq 1 ]; then
    gpg --batch --yes --armor --detach-sign --local-user "$GPG_KEY" \
      --output "${output_file}.asc" "$output_file"
    printf 'release-manifest: signed %s\n' "${output_file}.asc" >&2
  fi
else
  cat "$manifest_tmp"
  if [ "$sign" -eq 1 ]; then
    echo "release-manifest: --sign requires an output file" >&2
    exit 1
  fi
fi
