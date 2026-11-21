# Cybroid OS build guide

One repository produces every Cybroid OS artifact from
`common/branding/brand.toml`. Build inside the devcontainer (`.devcontainer/`)
or a Debian 13 host. Never build in the workstation that holds customer data.

## 0. Prerequisites

```sh
tools/preflight.sh
```

Install what is missing: `git python3 python3-toml build-essential dpkg-dev
fakeroot debhelper lintian shellcheck qemu-utils docker.io`.

## 1. Shared packages

```sh
tools/build-package.sh cybroidos-base
tools/build-package.sh cybroidos-kiosk
tools/build-package.sh cybroidos-rpi
tools/build-package.sh cybroidos-desktop
tools/build-package.sh cybroidos-desktop-lite
tools/build-package.sh cybroidos-server
tools/build-package.sh cybroidos-control   # D-Bus control service (v0 skeleton)
```

Output: `dist/cybroidos-<name>_<version>_all.deb`. A package directory with a
`debian/no-branding` marker is a metapackage: it ships dependency metadata only.

`tools/render-xfce-brand.py --brand common/branding/brand.toml --out DIR` renders
the shared Xfce look (wallpaper, GTK accent, backdrop, session wrapper and media
profile) used by the desktop Lite ISO, server qcow2 and pod-desktop. Target
builders call it automatically; the version and palette come only from
`brand.toml`.

## 2. Raspberry Pi kiosk image

```sh
EDITION=core targets/rpi/build.sh          # cage + Chromium kiosk
EDITION=education targets/rpi/build.sh
EDITION=core KIOSK_FLUTTER=1 targets/rpi/build.sh   # see note below
```

The builder builds the shared `.deb`s, stages them into the pi-gen rootfs and
installs them in `03-packages.sh`. Output: `targets/rpi/deploy/`.

To use the Flutter kiosk runtime, first build the minimal bundle:

```sh
tools/build-kiosk-flutter.sh
```

This requires the Flutter SDK and writes `MODE=flutter` into the staged
`kiosk.conf`. Without it the image uses `cage-chromium`.

## 3. Desktop ISO

```sh
DESKTOP=plasma EDITION=core targets/desktop/build.sh
DESKTOP=xfce EDITION=core targets/desktop/build.sh
```

See `targets/desktop/README.md`.

## 4. Server qcow2 + cloud-init image

```sh
EDITION=core targets/server/build.sh
```

See `targets/server/README.md`.

## 5. Docker / pod images

```sh
targets/docker/build.sh --stack generic
targets/docker/build.sh --stack python
targets/docker/build.sh --stack node
PUSH=1 targets/docker/build.sh
```

See `targets/docker/README.md`.

## 6. Release artifacts

```sh
tools/release-manifest.sh --edition core targets/rpi/deploy out/manifest-core.md
REPO_SIGNING_KEY=<key-id> apt-repo/publish.sh dist/incoming trixie
```

Set `GPG_KEY` and use `--sign` to detach-sign manifests. Signing material stays
in CI secrets or a secure release host; it is never committed.

## 7. Validation

```sh
tests/qemu/rpi-boot-test.sh <image>
tests/desktop/iso-smoke-test.sh <iso>
tests/server/smoke-test.sh <qcow2>
tests/container/smoke-test.sh
```

QEMU checks are structural/emulation checks. They are **not** hardware
validation; complete `docs/release/HARDWARE-CHECKLIST.md` before a release.
