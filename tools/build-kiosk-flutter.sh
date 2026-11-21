#!/usr/bin/env bash
# Build the minimal Flutter kiosk bundle for flutter-pi (ADR-0002).
#
# Usage: tools/build-kiosk-flutter.sh [bundle-dir] [kiosk-conf]
#
# With no arguments the bundle and config are written into the source tree's
# stage files, which makes the working tree dirty. Builders should pass the
# staged paths under targets/rpi/work/pi-gen/ so the repository stays clean.
# If the Flutter SDK is not installed the script exits with a clear message;
# the default cage+Chromium kiosk runtime is unaffected.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app="${repo_root}/apps/kiosk/flutter"
stage="${repo_root}/targets/rpi/stage-cybroidos/00-cybroidos/files"
bundle="${1:-${stage}/usr/share/cybroidos/kiosk/flutter_bundle}"
kiosk_conf="${2:-${stage}/etc/cybroidos/kiosk.conf}"
logo="${repo_root}/common/branding/logo/cybroid-logo.png"

if ! command -v flutter >/dev/null 2>&1; then
  echo "build-kiosk-flutter: flutter SDK not found; skipping Flutter bundle" >&2
  exit 1
fi
[ -f "$logo" ] || { echo "build-kiosk-flutter: missing brand logo: $logo" >&2; exit 1; }

install -d "${app}/assets"
cp "$logo" "${app}/assets/logo.png"

echo "build-kiosk-flutter: fetching Dart dependencies"
( cd "$app" && flutter pub get )

echo "build-kiosk-flutter: building flutter-pi bundle"
# --target-platform=linux-arm64 and --release produce a bundle flutter-pi can
# load on the Raspberry Pi. The output path is stable and safe to overwrite.
( cd "$app" && flutter build bundle \
    --release \
    --target-platform=linux-arm64 \
    --asset-dir="${bundle}" )

# Record which runtime the image should launch.
if grep -q '^MODE=' "${kiosk_conf}"; then
  sed -i "s/^MODE=.*/MODE=${KIOSK_MODE:-flutter}/" "${kiosk_conf}"
else
  printf 'MODE=%s\n' "${KIOSK_MODE:-flutter}" >> "${kiosk_conf}"
fi

echo "build-kiosk-flutter: bundle ready at ${bundle}"
echo "build-kiosk-flutter: kiosk.conf set to MODE=${KIOSK_MODE:-flutter}"
