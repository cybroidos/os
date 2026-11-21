# Cybroid OS — security posture

Date: 2026-11-21
Scope: repo `cybroidtech/os`, branch `public-release-prep`. The reviewed
workstation is a development machine, not the product image; its local firewall
and credentials are not part of any released artifact.

## Strengths

- No secrets, tokens, private keys or default passwords are committed;
  `.gitignore` excludes `.env`, `*.pem`, `*.key`, `*.asc` and `secrets/`.
- CI is least-privilege (`permissions: contents: read`) and runs in Debian 13
  containers matching the shipping base.
- No privileged builds in CI; the package declares `Rules-Requires-Root: no`.
- Branding is validated in CI (`brand.toml` parse, file existence, shellcheck /
  `bash -n` gates).
- The kiosk runs as an unprivileged user and Chromium is **not** launched with
  `--no-sandbox`.
- Licence and proprietary-component boundaries are explicit: GPL code,
  CC BY-NC artwork, a trademark policy and `tools/check-proprietary.sh`, which
  excludes non-free components unless `INCLUDE_PROPRIETARY=1` and the component
  is registered in `docs/PROPRIETARY-COMPONENTS.md`.
- Debian 13 provides a mainstream security-update pipeline once an update
  channel exists.

## Completed hardening (2026-11-21)

| Earlier finding | Status | Implementation |
|---|---|---|
| Default password and password SSH in `targets/rpi/config` | **Fixed** | No static password; SSH off; `PUBKEY_ONLY_SSH=1`; one-time random bootstrap password generated at build time |
| No first-boot identity hygiene | **Fixed** | `cybroidos-first-boot.service` regenerates machine-id and SSH host keys, installs a provisioning key, forces password change, sets deny-incoming firewall |
| Unhardened Chromium kiosk | **Fixed** | `--no-first-run`, `--disable-sync`, `--incognito`, tmpfs-backed `--user-data-dir` under `/run` |
| No signed update channel | **Tooling implemented** | `apt-repo/publish.sh` publishes and signs `InRelease` with reprepro; deployment pending |
| No signed release integrity / SBOM | **Tooling implemented** | `tools/release-manifest.sh --edition --packages-file --sign`; signing key/CI wiring pending |
| No `SECURITY.md` / CVE SLA | **Fixed** | `docs/SECURITY.md` with reporting address, acknowledgement (3 days), triage (10 days) and fix targets (30/90 days) |
| No edition security flags | **Fixed** | `editions/*/config`; security-sensitive flags default to off |
| No per-target metapackages | **Fixed** | `cybroidos-kiosk`, `-rpi`, `-desktop`, `-desktop-lite`, `-server` |
| No `INCLUDE_PROPRIETARY` guard | **Fixed** | `tools/check-proprietary.sh` called from both build tools |
| No end-user docs | **Fixed** | `docs/user/INSTALL.md`, `FIRST-BOOT.md`, `UPDATES.md`, `RECOVERY.md`, `SUPPORT.md` |
| No build guide / contributor docs | **Fixed** | `docs/BUILD-GUIDE.md`, `ADD-PACKAGE.md`, `SWAP-KIOSK-APP.md`, `ADD-HARDWARE-TARGET.md` |
| No hardware signoff process | **Fixed** | `docs/release/HARDWARE-CHECKLIST.md` and `docs/RELEASE-CHECKLIST.md` |

## Open findings

### P1 — before a scaled rollout

1. **Deploy the signed APT repo.** The tooling exists but no host, signing key
   or client keyring has been provisioned. Security fixes cannot reach devices
   until this is live.
2. **Wire GPG signing into CI/release.** `tools/release-manifest.sh --sign`
   needs a `GPG_KEY` secret and an output file in the release workflow.
3. **Kiosk physical-access exposure.** tty1 autologin still drops anyone at the
   kiosk session. Need session lockdown, no shell escape, a read-only rootfs or
   verified overlay, and a defined crash/restart policy. Verify on real hardware.
4. **Supply chain:** CI uses `actions/checkout@v5` and
   `actions/upload-artifact@v4` by mutable tag. `tools/pin-actions.sh` can pin
   them to commit SHAs once reviewed.
5. **No full-disk encryption for server/pod images** that may hold customer
   data (flagged `ENABLE_FDE=1` for Professional/Enterprise, not implemented).
6. **No Secure Boot / signed-image / verified-boot or TPM story** for the
   Enterprise edition (`ENABLE_SECURE_BOOT=1`, not implemented).
7. **No service-hardening baseline in the image targets** — the first-boot
   firewall sets defaults, but there is no broader hardening profile.
8. **Proprietary EULA packaging:** the guard warns, but no image actually
   attaches vendor EULAs when `INCLUDE_PROPRIETARY=1`.
9. **Real-hardware validation:** `docs/release/HARDWARE-CHECKLIST.md` is empty.
10. **Audit logging and MDM** are flagged for Education/Enterprise but not
    implemented.

### P2 — later

11. Secrets management for device pairing/relay (ADR-0004 WireGuard follow-up
    is open).
12. Reproducible-build verification and binary provenance.
13. Localisation and accessibility review.

## Controls by edition

See `docs/EDITION-STRATEGY.md` and `editions/*/config`.

- **Core / Education:** no default credentials, kiosk lockdown, signed updates,
  baseline firewall.
- **Developer:** pubkey-only SSH, local firewall, no autologin on
  network-facing interfaces.
- **Professional:** full-disk encryption, screen lock, remote access behind
  authentication (planned).
- **Enterprise / Security:** Secure Boot, signed images, FDE, MDM, audit and a
  CVE SLA with an SBOM per release (planned).

## Release security checklist

See `docs/RELEASE-CHECKLIST.md` for the complete gate.

- [x] No default password; first-boot password change enforced
- [x] SSH off by default; pubkey-only if enabled; no root login
- [x] `machine-id` and SSH host keys regenerated on first boot
- [x] Manifest generator supports signed checksums and SBOM
- [x] `SECURITY.md` with a reporting contact and response SLA
- [ ] Signed APT repo deployed and `InRelease` verified
- [ ] GPG signing key wired into the release workflow
- [ ] Actions pinned to commit SHAs
- [ ] Kiosk session lockdown verified on real hardware
- [ ] Proprietary components absent or explicitly opted in with a EULA
