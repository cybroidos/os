#!/usr/bin/env bash
# CIT-OS preflight: report whether the build toolchain is present.
# Run inside the devcontainer (docs/dev-environments.md) or on a build host.
set -euo pipefail

# name:command used to print the version
checks=(
  "git:git --version"
  "docker:docker --version"
  "python3:python3 --version"
  "mmdebstrap:mmdebstrap --version"
  "debootstrap:debootstrap --version"
  "lb:lb --version"
  "qemu-system-aarch64:qemu-system-aarch64 --version"
  "qemu-system-x86_64:qemu-system-x86_64 --version"
  "qemu-img:qemu-img --version"
  "shellcheck:shellcheck --version"
  "rsvg-convert:rsvg-convert --version"
)

missing=0
for entry in "${checks[@]}"; do
  name="${entry%%:*}"
  cmd="${entry#*:}"
  if command -v "${name}" >/dev/null 2>&1; then
    # shellcheck disable=SC2086  # $cmd is intentionally word-split into argv
    printf '  ok   %-22s %s\n' "${name}" "$(${cmd} 2>&1 | head -n1)"
  else
    printf '  MISS %-22s (not installed)\n' "${name}"
    missing=$((missing + 1))
  fi
done

echo
if [ "${missing}" -eq 0 ]; then
  echo "preflight: all tools present"
else
  echo "preflight: ${missing} tool(s) missing (see docs/dev-environments.md)"
fi
