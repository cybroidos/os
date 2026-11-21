# Installing Cybroid OS

## Raspberry Pi (Core / Education)

1. Download the `.img.xz` for your edition from the release page and verify its
   SHA-256 checksum against `manifest.md`:
   ```sh
   sha256sum cybroid-os-core-rpi-*.img.xz
   ```
2. Flash it to a microSD card (32 GB or larger) with Raspberry Pi Imager or
   `dd`. The image is ARM64 and is intended for Raspberry Pi 3/4.
3. Insert the card, connect power and a display, and boot. The first boot
   performs identity hygiene and may take a few minutes.

## Desktop ISO

Not yet released. See `docs/END-USER-READINESS.md`.

## Provisioning an administrator

The image contains **no default password**. Before first boot you may place an
SSH public key at `/etc/cybroidos/provision.pub` in the boot partition overlay
(see `editions/README.md`) to enable pubkey-only SSH. Otherwise SSH stays off.

At the first interactive login you will be asked to set a real password.
