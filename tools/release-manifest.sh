#!/usr/bin/env bash
# Generate a reproducible release manifest for Cybroid OS artifacts.
# Usage: tools/release-manifest.sh [artifact-dir] [output-file]
set -euo pipefail

usage() {
  printf 'usage: %s [artifact-dir] [output-file]\n' "${0##*/}" >&2
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

artifact_dir="${1:-out}"
output_file="${2:-}"

if [ ! -d "$artifact_dir" ]; then
  printf 'release-manifest: artifact directory not found: %s\n' "$artifact_dir" >&2
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
  printf '# Cybroid OS release manifest\n\n'
  printf 'generated_utc: %s\n' "$generated"
  printf 'git_commit: %s\n' "$commit"
  printf 'git_branch: %s\n' "$branch"
  printf 'brand_version: %s\n\n' "$version"

  printf '## Artifacts (sha256)\n\n'
  artifact_count=0
  while IFS= read -r -d '' artifact; do
    artifact_count=$((artifact_count + 1))
    checksum="$(sha256sum "$artifact" | awk '{print $1}')"
    printf '%s  %s\n' "$checksum" "${artifact#"$repo_root"/}"
  done < "$artifact_tmp"
  if [ "$artifact_count" -eq 0 ]; then
    printf '(no release artifacts found in %s)\n' "$artifact_dir"
  fi

  printf '\n## Build-host manual packages\n\n'
  if command -v apt-mark >/dev/null 2>&1; then
    apt-mark showmanual | sort | sed 's/^/- /'
  else
    printf '(apt-mark unavailable)\n'
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
else
  cat "$manifest_tmp"
fi
