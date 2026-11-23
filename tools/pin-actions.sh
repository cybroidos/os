#!/usr/bin/env bash
# Pin mutable GitHub Actions tag references to commit SHAs.
#
# Usage: tools/pin-actions.sh [workflow-file ...]
#   with no arguments, processes .github/workflows/*.yml
#
# Requires `gh` authenticated with API access. This is intentionally a manual
# maintenance tool: run it after reviewing upstream action releases.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

workflows=("$@")
if [ "$#" -eq 0 ]; then
  workflows=(.github/workflows/*.yml)
fi

command -v gh >/dev/null 2>&1 || { echo "pin-actions: gh is required" >&2; exit 1; }

for wf in "${workflows[@]}"; do
  [ -f "$wf" ] || { echo "pin-actions: not found: $wf" >&2; continue; }
  tmp="$(mktemp)"
  cp "$wf" "$tmp"
  # Matches: uses: owner/repo@vN  (already-pinned refs with a comment are skipped)
  while IFS= read -r line; do
    ref="$(printf '%s\n' "$line" | sed -nE 's/^([[:space:]]*uses:[[:space:]]*)([A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+)@(v[0-9]+)([[:space:]]*)$/\2 \3/p')"
    [ -n "$ref" ] || continue
    repo="${ref% *}"
    tag="${ref##* }"
    sha="$(gh api "repos/${repo}/git/ref/tags/${tag}" -q '.object.sha' 2>/dev/null || true)"
    if [ -z "$sha" ]; then
      sha="$(gh api "repos/${repo}/commits/${tag}" -q '.sha' 2>/dev/null || true)"
    fi
    if [ -z "$sha" ]; then
      echo "pin-actions: could not resolve ${repo}@${tag}; left unchanged" >&2
      continue
    fi
    sed -i "s|uses: ${repo}@${tag}\$|uses: ${repo}@${sha} # ${tag}|" "$tmp"
    echo "pin-actions: ${repo}@${tag} -> ${sha}"
  done < <(grep -nE 'uses:[[:space:]]*[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+@v[0-9]+[[:space:]]*$' "$wf" | cut -d: -f2-)
  if ! cmp -s "$wf" "$tmp"; then
    cp "$tmp" "$wf"
    echo "pin-actions: updated $wf"
  fi
  rm -f "$tmp"
done
