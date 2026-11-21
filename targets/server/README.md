# Cybroid OS server / pods image (Phase 5)

Builds a **Debian 13 "Trixie" x86_64** cloud-init-capable qcow2 VM image with
**Xfce 4.20** (ADR-0003), **RDP via xrdp primary + noVNC fallback** (ADR-0005),
headless **`kcd`** for phone control (ADR-0004/0005), OpenSSH and the shared
Cybroid branding from `common/branding/brand.toml` via `cybroidos-base`.

This target owns only `targets/server/**`; the shared `.deb` packages are built
from `common/packages/` by `tools/build-package.sh`.

## Prerequisites

On a Debian/Ubuntu build host (run as root; loop devices and chroot are needed):

```sh
sudo apt-get update
sudo apt-get install -y --no-install-recommends \
  mmdebstrap debootstrap qemu-utils genisoimage dosfstools e2fsprogs \
  fdisk util-linux dpkg-dev debhelper fakeroot python3 curl ca-certificates
```

- `mmdebstrap` is preferred; `debootstrap` is the fallback.
- `genisoimage` is preferred for the NoCloud seed; `xorriso` also works.
- `kcd` is not in Debian yet: the build downloads the **official upstream
  signed-by-checksum `.deb`** (pinned version + SHA-256). Set `KCD_VERSION` and
  `KCD_SHA256` together to update it. If Debian later packages `kcd`, apt is
  used automatically.
- An SSH **public key file** is mandatory; there is no default password and no
  key is stored in this repository.

## Build

```sh
# Use an edition's provisioning key, or point PUBKEY_FILE at your own .pub file.
EDITION=core ARCH=x86_64 SIZE=8G \
  PUBKEY_FILE=/path/to/admin.pub \
  targets/server/build.sh
```

Environment variables:

| Variable | Default | Meaning |
|---|---|---|
| `EDITION` | `core` | Must have an `editions/<edition>/config` file. |
| `ARCH` | `x86_64` | `amd64` is accepted; other architectures are rejected. |
| `OUT_DIR` | `targets/server/deploy` | Artifact directory. |
| `SIZE` | `8G` | Raw disk size before qcow2 conversion. |
| `WORK_DIR` | `targets/server/work` | Rootfs/raw disk staging (deleted contents). |
| `PUBKEY_FILE` | `editions/<edition>/provision.pub` | SSH public key injected into cloud-init user-data. |
| `MIRROR`, `SUITE`, `RELEASE` | `http://deb.debian.org/debian`, `trixie`, `trixie` | Bootstrap source / os-release codename. |
| `KCD_VERSION`, `KCD_SHA256` | `2.0.1`, pinned upstream checksum | kcd provenance. |

Artifacts (version comes from `brand.toml`):

```
cybroid-os-<edition>-server-<arch>-<version>.qcow2
cybroid-os-<edition>-server-<arch>-<version>-cloud-init.iso
SHA256SUMS-<edition>-<arch>-<version>
```

The qcow2 is GPT-partitioned (BIOS boot + EFI system + ext4 root, labelled
`cybroidos-root`) and has GRUB installed for both BIOS and UEFI. The seed ISO is
a cloud-init **NoCloud** disk (`-volid cidata`) carrying `user-data` and
`meta-data`; `user-data` is rendered from `config/cloud-init/user-data.tmpl`
with the key from `PUBKEY_FILE` (never a hardcoded key).

## Launch with QEMU/KVM

```sh
qemu-system-x86_64 -enable-kvm -m 2048 -smp 2 \
  -drive file=cybroid-os-core-server-x86_64-0.1.0.qcow2,if=virtio,format=qcow2 \
  -drive file=cybroid-os-core-server-x86_64-0.1.0-cloud-init.iso,media=cdrom,readonly=on \
  -netdev user,id=net0,hostfwd=tcp::2222-:22,hostfwd=tcp::3389-:3389,hostfwd=tcp::6080-:6080 \
  -device virtio-net-pci,netdev=net0
```

- **SSH**: host port 2222 → guest 22, user `cybroid`, your public key only.
- **RDP (primary)**: host port 3389 → guest 3389 (`xrdp` + Xfce via
  `config/xrdp/`).
- **noVNC (fallback)**: host port 6080 → guest 6080
  (`websockify --web=/usr/share/novnc` → local `x11vnc` on 5900; open
  `http://localhost:6080/` in a browser).
- **kcd**: KDE Connect ports 1716/tcp+udp and 1739–1764/tcp, restricted by the
  first-boot firewall to RFC1918 networks.

First boot runs `/usr/bin/cybroidos-first-boot` (also a `ConditionFirstBoot`
systemd unit): fresh machine-id and SSH host keys, `chage -d 0` so any later
password must be changed, and a deny-by-default ufw baseline. No password is
baked into the image; `sshd_config.d/90-cybroidos.conf` enforces pubkey-only
login and forbids root login.

## Configuration files

| Path | Installed as |
|---|---|
| `config/server.conf` | `/etc/cybroidos/server.conf` |
| `config/xfce-session` | `/etc/cybroidos/xfce-session` (Xfce + xrdp/noVNC launcher) |
| `config/cloud-init/90-cybroidos.cfg` | `/etc/cloud/cloud.cfg.d/90-cybroidos.cfg` |
| `config/xrdp/{xrdp.ini,startwm.sh}` | `/etc/xrdp/` |
| `config/novnc/novnc.conf` | `/etc/cybroidos/novnc.conf` |
| `config/xfce/xfce4-desktop.xml` | Xfce default wallpaper |
| `config/lightdm/*`, `config/sddm/*` | greeter branding |
| `config/sshd/90-cybroidos.conf` | `/etc/ssh/sshd_config.d/` |
| `config/systemd/*` | Cybroid first-boot, Xfce session and kcd units |

`hooks/` contains the build-time scripts (local `.deb` install, kcd provenance
check, branding, cloud-init config, service enablement, cleanup, seed render).
The same Xfce + xrdp/noVNC configuration is intended to be reused by
`cybroidos-pod-desktop` (ADR-0005); no container-specific hacks are in the VM.

## Validation

```sh
bash -n targets/server/build.sh targets/server/hooks/*.sh \
  targets/server/config/xfce-session targets/server/config/xrdp/startwm.sh
tests/server/smoke-test.sh cybroid-os-core-server-x86_64-0.1.0.qcow2 \
  cybroid-os-core-server-x86_64-0.1.0-cloud-init.iso
```

See `tests/server/README.md`. Full builds are intentionally **not** run as
part of repository validation — they require root, loop devices and a Debian
mirror. QEMU/KVM boot is emulation, **not** hardware validation; real-host RDP,
GPU and USB behaviour still needs the Phase 7 hardware checklist.
