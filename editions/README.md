# Cybroid OS editions

Each directory here defines one product edition as build-time shell flags that
are appended to the generated pi-gen config by `targets/rpi/build.sh`. Select an
edition with `EDITION=<name> targets/rpi/build.sh`.

Editions are chosen at **build time**, not runtime, so every image is immutable
and can be signed and manifested independently. See
[`docs/EDITION-STRATEGY.md`](../docs/EDITION-STRATEGY.md).

| Edition | Purpose |
|---|---|
| `core` | Free open base: branded boot, kiosk, signed updates |
| `education` | Core + classroom/kiosk management, managed update window |
| `developer` | Core + devcontainers, SDKs, pubkey-only SSH |
| `professional` | Core + desktop, office, remote desktop, optional add-ons |
| `enterprise` | Professional + Secure Boot, FDE, MDM, audit |

## Flag reference

- `ENABLE_KIOSK_MODE` — autologin kiosk on tty1
- `ENABLE_CLASSROOM_TOOLS` — teacher/classroom tooling
- `ENABLE_DEVCONTAINERS` — Docker + devcontainer tooling
- `ENABLE_REMOTE_DESKTOP` — RDP/VNC services
- `INCLUDE_PROPRIETARY` — must be explicitly set to `1`; see
  `docs/PROPRIETARY-COMPONENTS.md`
- `ENABLE_FDE` — full-disk encryption at provisioning
- `ENABLE_MDM` — management agent and audit logging

Security-sensitive flags default to `0`. To drop in an SSH provisioning key,
place `provision.pub` in the edition directory or set `PUBKEY_FILE`.
