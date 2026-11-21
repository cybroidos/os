# Desktop ISO smoke test

`iso-smoke-test.sh` verifies a Cybroid OS desktop ISO. It is deliberately
**rootless**: it reads the ISO with `isoinfo`/`xorriso` and extracts individual
files from the live SquashFS with `unsquashfs`; it does not loop-mount anything.
QEMU uses `-nographic`/serial console, so no desktop or root shell is needed.

> **QEMU is not real hardware.** A passing run proves the image's filesystem,
> branding and package manifest are consistent and that its kernel/systemd boot
> in emulation. It does not validate physical boot, firmware/Secure Boot,
> graphics drivers, Wi-Fi or lab peripherals. See `docs/PLAN.md` ground rule 4
> and `docs/release/HARDWARE-CHECKLIST.md`.

## Requirements

- `genisoimage` (for `isoinfo`) **or** `xorriso`
- `squashfs-tools` (for `unsquashfs`) — optional but needed for file-level checks
- `qemu-system-x86_64` (or `qemu-system-aarch64` with `ARCH=arm64`) and
  `qemu-utils` for the boot step
- Optional: writable `/dev/kvm`; without it QEMU falls back to slow TCG

## Usage

```sh
# Fast, filesystem-only inspection (used in CI)
SKIP_BOOT=1 tests/desktop/iso-smoke-test.sh dist/desktop/*.iso

# Full check: ISO inspection + headless QEMU boot
tests/desktop/iso-smoke-test.sh dist/desktop/*.iso --desktop plasma
tests/desktop/iso-smoke-test.sh dist/desktop/core-lite*.iso --desktop xfce
```

Options/env: `--desktop plasma|xfce`, `--skip-boot` (same as `SKIP_BOOT=1`),
`ARCH`, `QEMU`, `MEM` (default 4096 MB), `BOOT_TIMEOUT` (default 180 s),
`QEMU_EXTRA` (extra QEMU arguments).

## What is asserted

Fatal checks:

1. `/live/vmlinuz*`, `/live/initrd*`, `/live/filesystem.squashfs` and
   `/live/filesystem.packages` exist on the ISO.
2. The package manifest contains `cybroidos-base`, `cybroidos-desktop`,
   `calamares`, `plasma-desktop` (or `xfce4`), `kdeconnect`, `krdp` and
   `cybroidos-control`. `kcd` is accepted when present; Debian 13 main has no
   standalone `kcd`, so `kdeconnect` satisfies the desktop daemon check.
3. With `unsquashfs`: `/usr/lib/os-release` has `ID=cybroidos`, hostname is
   `cybroid`, MOTD/issue carry the brand, `desktop.conf` selects the expected
   variant, SDDM uses the `cybroidos` theme, Calamares branding carries the
   product name/vendor, and the dpkg status says all expected packages are
   installed.
4. Unless `SKIP_BOOT=1`: the ISO's own kernel and initrd boot under QEMU with a
   serial console and Linux/systemd activity is observed.

The boot log is written to a temporary directory and removed on exit.
