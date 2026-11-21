# Cybroid OS — security posture

Date: 2026-11-21
Scope: repo at commit `8f0e5ba`. The reviewed workstation is a development
machine, not the product image; its local firewall and credentials are not part
of any released artifact.

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
- Licence and proprietary-component boundaries are explicit (PR #1):
  GPL code, CC BY-NC artwork, a trademark policy and a register of non-free
  components kept out of the public image.
- Debian 13 provides a mainstream security-update pipeline once an update
  channel exists.

## Findings (priority order)

### P0 — must fix before any release

1. **Default password and password SSH.** `targets/rpi/config` has
   `FIRST_USER_PASS='cybroidos'`, `ENABLE_SSH='1'`, `PUBKEY_ONLY_SSH='0'`. Fix:
   no default password, SSH disabled by default and pubkey-only when enabled,
   forced password change, and drop `DISABLE_FIRST_BOOT_USER_RENAME`.
2. **No signed update channel.** ADR-0007 commits to reprepro + signed
   `InRelease`, but `apt-repo/` does not exist. Security fixes cannot reach
   devices; users would have to reflash.
3. **No release integrity.** Artifacts have no signed checksums or image SBOM.
   `tools/release-manifest.sh` emits checksums but does not sign them.
4. **Kiosk physical-access exposure.** tty1 autologin drops anyone at the
   kiosk session. Need session lockdown, no shell escape, a read-only rootfs or
   verified overlay, and a defined crash/restart policy.

### P1 — before a scaled rollout

5. **Supply chain:** CI uses `actions/checkout@v5` and
   `actions/upload-artifact@v4` by mutable tag. Pin to commit SHAs.
6. No `SECURITY.md`, vulnerability reporting address or CVE response SLA.
7. No full-disk encryption for server/pod images that may hold customer data.
8. No Secure Boot / signed-image / verified-boot or TPM story for an Enterprise
   edition.
9. No firewall or service-hardening baseline in the image targets — the dev
   workstation's UFW rules are not part of the product.
10. Chromium kiosk hardening: consider `--no-first-run`, `--disable-sync`,
    `--incognito`, a tmpfs `--user-data-dir`, and review the auto-restart policy.
11. The proprietary-component register exists, but no build-time guard
    (`INCLUDE_PROPRIETARY=1`) is implemented in any script.
12. Image identity hygiene is undefined: `/etc/machine-id`, SSH host keys and
    user keys must be cleared/regenerated on first boot for distributed images.

### P2 — later

13. Audit logging, central log shipping and an MDM/management agent for
    Enterprise.
14. Secrets management for device pairing/relay (ADR-0004 WireGuard follow-up
    is open).
15. Reproducible-build verification and binary provenance.

## Controls by edition

See `docs/EDITION-STRATEGY.md`.

- **Core / Education:** no default credentials, kiosk lockdown, signed updates,
  optional read-only rootfs.
- **Developer:** pubkey-only SSH, local firewall, no autologin on network-facing
  interfaces.
- **Professional:** full-disk encryption, screen lock, remote access behind
  authentication.
- **Enterprise / Security:** Secure Boot, signed images, FDE, MDM, audit and a
  CVE SLA with an SBOM per release.

## Release security checklist

- [ ] No default password; first-boot password change enforced
- [ ] SSH off by default; pubkey-only if enabled; no root login
- [ ] `machine-id` and SSH host keys regenerated on first boot
- [ ] Signed APT repo + signed image checksums + SBOM attached
- [ ] CI actions pinned to commit SHAs
- [ ] `SECURITY.md` with a reporting contact and response SLA
- [ ] Kiosk session lockdown verified on real hardware
- [ ] Proprietary components absent or explicitly opt-in with a EULA
