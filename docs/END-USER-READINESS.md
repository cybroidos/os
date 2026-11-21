# Cybroid OS — end-user readiness assessment

Date: 2026-11-21
Reviewed: repo `cybroidtech/os` (branch `public-release-prep`) and the developer
workstation. **The workstation is not the shipping product.**

## Verdict

**Not ready for end users yet**, but the engineering foundations are now in
place. This is a strong build system (ADRs, CI, single-source branding, helper
scripts) with one partially complete Raspberry Pi kiosk target. Desktop, server
and Docker are designs, not code.

Scores are judgement calls based on the repo, not benchmark results. The
"after" column reflects the implementation work completed on 2026-11-21.

| Area | Was | Now | Note |
|---|---|---|---|
| Build / reproducibility | 7/10 | 7/10 | Clean CI, Debian 13 containers, one brand source; no reproducible-build verification |
| Pi kiosk image | 5/10 | 6/10 | Editions matrix + hardened kiosk/manifest; no Pi 4 hardware signoff |
| Desktop ISO | 1/10 | 1/10 | Planned only (ADR-0003, Calamares) |
| Server / pods / Docker | 1/10 | 1/10 | Planned only (ADR-0005) |
| First-run experience | 2/10 | 6/10 | No default password, pubkey-only SSH, first-boot hygiene and forced password change; no welcome/setup UI |
| Branding consistency | 7/10 | 7/10 | os-release, motd, issue, Plymouth and kiosk from `brand.toml`; palette/wallpaper unconfirmed |
| Updates / lifecycle | 1/10 | 4/10 | `apt-repo/publish.sh` signs `InRelease`; not deployed, no update UI or rollback |
| End-user docs / support | 2/10 | 6/10 | Install, first boot, updates, recovery and support guides added; not validated by a user |
| Localisation / accessibility | 1/10 | 1/10 | en_US / US keyboard only; no accessibility review |
| Licensing / legal | 6/10 | 6/10 | GPL + CC BY-NC + NOTICE in PR #1; owner sign-off pending |

## What works today

- CI validates required files, `brand.toml`, shell syntax and builds
  `cybroidos-base` in a Debian 13 container.
- The Pi image builds in GitHub Actions as a **Core × Education matrix** and
  passes structural checks: partition layout, `ID=cybroidos`, hostname `cybroid`,
  branded banners and assets.
- Branding is centralised: `common/branding/brand.toml` → `tools/render-brand.py`
  → os-release, motd, issue, kiosk page and Plymouth theme.
- Kiosk boots quietly to a branded splash, then a runtime-agnostic fullscreen
  app (Flutter primary, cage + Chromium fallback) with an ephemeral Chromium
  profile and no first-run/sync prompts.
- `tools/release-manifest.sh` records commit, version, edition, checksums,
  per-image SBOM and the build host's manual package list; it can detach-sign
  the manifest when `GPG_KEY` is supplied.
- Release hygiene: no default password, SSH off unless a provisioning key is
  supplied, first-boot machine-id/host-key regeneration and forced password
  change, baseline deny-incoming firewall.
- Signed APT repository tooling (`apt-repo/publish.sh`) implements ADR-0007.
- End-user guides and a Pi 4 hardware checklist are in `docs/user/` and
  `docs/release/`.

## Remaining blockers before shipping to an end user

1. **No real-hardware validation.** The Definition of Done items in
   `docs/PLAN.md` §11 are unchecked. QEMU cannot boot the raw image and must
   never be reported as hardware validation. Use
   `docs/release/HARDWARE-CHECKLIST.md` on a Pi 4.
2. **Signed APT repo not yet deployed.** The tooling exists and emits a signed
   `InRelease`, but no host, key or client configuration has been provisioned.
3. **Release integrity not yet exercised in CI.** The manifest can sign, but
   no signing key is wired into the release workflow yet.
4. **Desktop / server / Docker are not implemented.** The README labels them
   planned; expectations must be aligned before promising a date.
5. **Brand assets are not final** — palette is pending brand-owner
   confirmation and there is no wallpaper art.
6. **No localisation or accessibility work** beyond en_US / US keyboard.
7. **Legal sign-off** on CC BY-NC for artwork and the trademark policy.
8. **Edition policy decisions** — final names, paid editions, support SLAs and
   which editions may include Hangar.

## Order of work from here

1. Complete the Pi 4 hardware checklist and the Definition of Done.
2. Deploy the signed APT repo and wire GPG signing into the release workflow.
3. Validate the first-run experience with a real provisioned device.
4. Start the desktop ISO Core and Education editions
   (see `docs/EDITION-STRATEGY.md`).
