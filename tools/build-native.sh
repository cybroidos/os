#!/usr/bin/env bash
# Builds CybroidOS's own desktop apps (apps/desktop: Cybroid.Ui, Settings,
# Camera) and packages them (cybroid-ui, cybroid-settings, cybroid-camera)
# for this machine's architecture.
#
# Needs Debian 13 (the Qt the packages run on) with:
#   cmake g++ qt6-base-dev qt6-declarative-dev qt6-multimedia-dev dpkg-dev
# CI runs it in a debian:trixie container (server-images.yml).
#
# Usage: tools/build-native.sh [out dir]      (default: dist/)
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "${here}/.." && pwd)"
out="${1:-${repo}/dist}"
NATIVE_PACKAGES="cybroid-ui cybroid-settings cybroid-camera"

build="$(mktemp -d)"
stage="$(mktemp -d)"
trap 'rm -rf "${build}" "${stage}"' EXIT

cmake -S "${repo}/apps/desktop" -B "${build}" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr >/dev/null
cmake --build "${build}" -j"$(nproc)"
for p in ${NATIVE_PACKAGES}; do
	DESTDIR="${stage}/${p}" cmake --install "${build}" --component "${p}" >/dev/null
	strip --strip-unneeded $(find "${stage}/${p}" -type f \( -name '*.so' -o -perm -u+x \) 2>/dev/null) 2>/dev/null || true
done
NATIVE_ROOT="${stage}" OUT="${out}" "${repo}/tools/build-package.sh" ${NATIVE_PACKAGES}
