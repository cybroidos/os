# Desktop ISO (`targets/desktop`)

Builds an **installable Debian 13 "Trixie" live ISO** for Cybroid OS with
Debian's official [`live-build`](https://packages.debian.org/trixie/live-build)
tooling. The ISO is hybrid (boots from optical media or a USB stick), uses
**Calamares** as the installer, and ships either **KDE Plasma 6.3** (default,
4 GB+) or **Xfce 4.20 "Lite"** (about 2 GB lab machines), per ADR-0003.

Branding is never duplicated here: `tools/render-brand.py` renders
`common/branding/brand.toml` into os-release, MOTD/issue, kiosk HTML and the
Plymouth theme; the chroot hooks copy those files (plus the logo/wallpaper) into
`/usr/share/cybroidos/branding`, `/usr/share/wallpapers/cybroidos/`, the SDDM
theme, the Plasma global theme, GRUB and Calamares branding.

## Prerequisites

On a Debian 13 (Trixie) build host or in the privileged `debian:13-slim`
container used by CI:

```sh
apt-get update
apt-get install -y --no-install-recommends \
  live-build debootstrap squashfs-tools xorriso genisoimage \
  qemu-utils dpkg-dev debhelper fakeroot python3 ca-certificates git
```

`lb build` must run as **root**. Nothing is installed into the engineer's host
outside this repo; the build tree is temporary and removed by default
(`KEEP_WORK=1` keeps it for debugging).

## Build

Build the shared branding package first (the ISO installs it as a local `.deb`):

```sh
tools/build-package.sh cybroidos-base
```

Then build an ISO:

```sh
# KDE Plasma (default), Core edition, x86_64
targets/desktop/build.sh

# Xfce 4.20 "Lite" for low-spec lab machines (~2 GB RAM)
DESKTOP=xfce targets/desktop/build.sh

# Explicit edition / architecture / output directory
BASE_EDITION=education DESKTOP=xfce ARCH=arm64 OUT_DIR=targets/desktop/out \
  targets/desktop/build.sh
```

Environment variables:

| Variable | Default | Meaning |
|---|---|---|
| `ARCH` | `amd64` | `amd64` or `arm64` (arm64 needs a capably configured cross-bootstrap host) |
| `DESKTOP` | `plasma` | `plasma` or `xfce` |
| `EDITION` | `core` | Release label; `xfce` appends `-lite` unless `EDITION` was set explicitly |
| `BASE_EDITION` | `core` | Which `editions/<name>/config` to load |
| `OUT_DIR` | `dist/desktop` | Where ISO + `.sha256` are written |
| `BASE_DEB` / `CONTROL_DEB` | auto-detect in `dist/` | Local package paths |
| `KEEP_WORK` | `0` | Set to `1` to keep the live-build work tree |

Artifacts are named:

```
cybroid-os-<edition>-desktop-<arch>-<version>.iso
# e.g. cybroid-os-core-desktop-amd64-0.1.0.iso
#      cybroid-os-core-lite-desktop-amd64-0.1.0.iso (Xfce)
```

A matching `.sha256` file is written beside each ISO. `cybroidos-desktop` is a
thin local meta-package (built on the fly) whose `Depends` line selects the
desktop, Calamares, KDE Connect, KRDP and the `cybroidos-control` service; it
contains no branding files of its own.

> `cybroidos-control` is built by a separate worker. If no
> `dist/cybroidos-control_*.deb` is staged and the package is not published to
> the APT repo yet, the build will fail loudly rather than ship an incomplete ISO.

## What is in the image

- `calamares` + `calamares-settings-debian`, re-branded to product name/vendor.
- KDE Plasma: `kde-plasma-desktop`, `plasma-desktop`, branded global theme and
  SDDM greeter; KDE Kiosk profile at `/etc/xdg/cybroidos-kiosk.conf`.
- Xfce Lite: `xfce4`, `xfce4-goodies`, `xorg` with the same greeter/wallpaper.
- `kdeconnect`, `krdp`, `cybroidos-control` for phone control (ADR-0004).
- Plymouth boot splash, branded GRUB theme and `/etc/issue`/`/etc/motd`.
- `/etc/cybroidos/desktop.conf` records the edition/desktop chosen at build.
- A first-boot service regenerates machine-id/SSH host keys and forces a
  password change; the image contains no default password or secret.

## Smoke test

See [`tests/desktop/README.md`](../../tests/desktop/README.md):

```sh
SKIP_BOOT=1 tests/desktop/iso-smoke-test.sh dist/desktop/*.iso
tests/desktop/iso-smoke-test.sh dist/desktop/*.iso --desktop plasma
```

QEMU checks are **not hardware validation**. Real-hardware sign-off is tracked
in `docs/release/HARDWARE-CHECKLIST.md`.
