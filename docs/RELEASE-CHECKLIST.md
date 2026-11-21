# Cybroid OS release checklist

Use this before tagging any image as released. It consolidates the P0/P1 items
from `docs/END-USER-READINESS.md` and `docs/SECURITY-POSTURE.md`.

## Security (P0)

- [ ] No default password in any generated config; `targets/rpi/config` has none
- [ ] SSH disabled by default; pubkey-only when enabled; no root login
- [ ] First-boot service regenerates machine-id and SSH host keys
- [ ] First login forces a password change
- [ ] Kiosk session lockdown verified on real hardware
- [ ] Signed APT repo published; `InRelease` verifies
- [ ] Release manifest generated with `--edition` and `--sign`
- [ ] Signed checksums and SBOM attached to the release

## Engineering

- [ ] `docs/release/HARDWARE-CHECKLIST.md` completed on Pi 4
- [ ] CI green (repo validation, package build, metapackage build, image matrix)
- [ ] Pi image smoke test passes (`tests/qemu/`)
- [ ] Desktop ISO smoke test passes (`tests/desktop/`) for Plasma and Lite
- [ ] Server qcow2 + cloud-init smoke test passes (`tests/server/`)
- [ ] Container smoke test passes for all pod images on amd64 and arm64
- [ ] Mobile control components versioned together (`cybroidos-control`,
      `cybroidos_connect`, Flutter client)
- [ ] Definition of Done in `docs/PLAN.md` §11 all checked
- [ ] Release manifest git commit matches the tagged commit
- [ ] No proprietary components present unless explicitly opted in

## Documentation and legal

- [ ] End-user docs under `docs/user/` match the shipped edition
- [ ] `SECURITY.md` contact and SLA confirmed
- [ ] `NOTICE.md`, `LICENSE`, `LICENSE-ASSETS` in the image/release notes
- [ ] Brand-owner sign-off on palette and wallpaper
- [ ] Legal name is Cybroid Technologies (U) Ltd everywhere

## Decisions still needed from the owner

1. Final edition names and which editions are paid.
2. Which editions may include proprietary components (Hangar today).
3. Support/SLA commitments per edition.
4. Brand-owner sign-off on palette, wallpaper and trademark wording.
5. Target hardware list for validation.
