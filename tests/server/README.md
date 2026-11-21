# Server image smoke tests

`smoke-test.sh` verifies a Cybroid OS server/pods qcow2 image produced by
`targets/server/build.sh`. It supports two modes:

## Offline (`SKIP_BOOT=1`)

Never boots the image and never mounts a partition on the host. It converts the
qcow2 to a raw copy inside a temporary directory with `qemu-img`, locates the
GPT root partition, and reads files with `debugfs`. Requires `qemu-utils`,
`e2fsprogs` and (if a seed ISO is supplied) `genisoimage` or `xorriso`.

```sh
SKIP_BOOT=1 tests/server/smoke-test.sh \
  out/server/cybroid-os-core-server-x86_64-0.1.0.qcow2 \
  out/server/cybroid-os-core-server-x86_64-0.1.0-cloud-init.iso
```

Assertions: `ID=cybroidos`, branded motd/issue, hostname `cybroid`, brand
assets, installed packages (`xfce4`, `xrdp`, `kcd`, `cloud-init`, `novnc`,
`x11vnc`, `openssh-server`, `cybroidos-*`), enabled systemd units, xrdp/noVNC
config, cloud-init NoCloud datasource, pubkey-only SSH config and a locked
`cybroid` password.

## Live QEMU/KVM (default)

Boots the qcow2 with KVM plus the cloud-init seed, waits for SSH, and runs the
same assertions inside the guest (plus serial-log checks for first boot).

```sh
SSH_PRIVATE_KEY=/path/to/admin.key \
tests/server/smoke-test.sh IMAGE.qcow2 SEED.iso
```

Requirements: `/dev/kvm` (or `KVM=0` for very slow TCG emulation),
`qemu-system-x86_64`, `openssh-client`, and the private key matching the public
key passed as `PUBKEY_FILE` at build time. Host ports default to 2222 (SSH),
3389 (RDP) and 6080 (noVNC); override with `SSH_PORT`, `RDP_PORT`, `NOVNC_PORT`.
`BOOT_TIMEOUT` defaults to 240 seconds.

If KVM is unavailable, `SKIP_BOOT=1` is the honest CI fallback: it inspects the
image but does **not** claim a boot or hardware validation. QEMU-only test
profiles stay in `tests/`; no emulation workaround is added to the shipping
image.
