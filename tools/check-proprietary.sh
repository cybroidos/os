#!/usr/bin/env bash
# Guard for non-free components.
#
# By default any build that would include proprietary software fails. Setting
# INCLUDE_PROPRIETARY=1 explicitly permits it, but only if the component is
# registered in docs/PROPRIETARY-COMPONENTS.md.
#
# Usage: tools/check-proprietary.sh <component-name>
set -euo pipefail

component="${1:-}"
if [ -z "$component" ]; then
  echo "check-proprietary: usage: ${0##*/} <component-name>" >&2
  exit 2
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
register="${repo_root}/docs/PROPRIETARY-COMPONENTS.md"

if [ "${INCLUDE_PROPRIETARY:-0}" != "1" ]; then
  echo "check-proprietary: '${component}' is proprietary and INCLUDE_PROPRIETARY is not 1; excluded"
  exit 0
fi

if [ ! -f "$register" ] || ! grep -qi -- "$component" "$register"; then
  echo "check-proprietary: '${component}' is not registered in docs/PROPRIETARY-COMPONENTS.md" >&2
  exit 1
fi

echo "WARNING: build explicitly INCLUDES proprietary component '${component}'" >&2
echo "WARNING: its vendor EULA must accompany the released image" >&2
