# Cybroid OS — end-user readiness assessment

Date: 2026-11-21
Reviewed: repo `cybroidtech/os` (branch `public-release-prep`, commit `8f0e5ba`)
and the developer workstation. **The workstation is not the shipping product.**

## Verdict

**Not ready for end users.** This is a strong engineering foundation (ADRs, CI,
single-source branding, reproducible helper scripts) with one partially complete
Raspberry Pi kiosk target. Desktop, server and Docker are designs, not code.
Scores are judgement calls based on the repo, not benchmark results.

| Area | Score | Note |
|---|---|---|
| Build / reproducibility | 7/10 | Clean CI, Debian 13 containers, one brand source; no reproducible-build verification |
| Pi kiosk image | 5/10 | Builds and passes structural checks; QEMU cannot boot the raw image; no Pi 4 hardware signoff |
| Desktop ISO | 1/10 | Planned only (ADR-0003, Calamares) |
| Server / pods / Docker | 1/10 | Planned only (ADR-0005) |
| First-run experience | 2/10 | Kiosk autologin works; dev password + password SSH still in config; no welcome/setup |
| Branding consistency | 7/10 | os-release, motd, issue, Plymouth and kiosk all from `brand.toml`; palette/wallpaper unconfirmed |
| Updates / lifecycle | 1/10 | Signed APT repo designed (ADR-0007) but `apt-repo/` absent; no update UI or rollback |
| End-user docs / support | 2/10 | Developer docs only; no install, recovery or support guide |
| Localisation / accessibility | 1/10 | en_US / US keyboard only; no accessibility review |
| Licensing / legal | 6/10 | GPL + CC BY-NC + NOTICE added in PR #1; owner sign-off pending |

## What works today

- CI validates required files, `brand.toml`, shell syntax and builds
  `cybroidos-base` in a Debian 13 container.
- The Pi image builds in GitHub Actions and passes structural checks: partition
  layout, `ID=cybroidos`, hostname `cybroid`, branded banners and assets.
- Branding is centralised: `common/branding/brand.toml` → `tools/render-brand.py`
  → os-release, motd, issue, kiosk page and Plymouth theme.
- Kiosk boots quietly to a branded splash, then a runtime-agnostic fullscreen
  app (Flutter primary, cage + Chromium fallback).
- `tools/release-manifest.sh` records commit, version, checksums and the build
  host's manual package list.

## Blockers before shipping to an end user

1. **Default credentials in the shipping config.**
   `targets/rpi/config` sets `FIRST_USER_PASS='cybroidos'`, `ENABLE_SSH='1'`,
   `PUBKEY_ONLY_SSH='0'` and `DISABLE_FIRST_BOOT_USER_RENAME='1'`. The comment
   says DEV IMAGE ONLY, but nothing enforces it. A release must have no default
   password, SSH off or pubkey-only, and a forced password change on first login.
2. **No real-hardware validation.** The Definition of Done items in
   `docs/PLAN.md` §11 are unchecked. QEMU cannot boot the raw image and must
   never be reported as hardware validation. A Pi 4 signoff checklist is needed.
3. **No update path.** No signed APT repo implementation, no signed release
   artifacts, no update/rollback experience, no CVE response SLA.
4. **No end-user documentation** — install, first boot, update, recovery,
   support and warranty/returns.
5. **Desktop / server / Docker are not implemented.** The README now labels
   them planned; expectations must be aligned before promising a date.
6. **Brand assets are not final** — palette is "pending brand-owner
   confirmation" and there is no wallpaper art.
7. **No localisation or accessibility work** beyond en_US / US keyboard.
8. **Legal sign-off** on CC BY-NC for artwork and the trademark policy.

## Suggested order of work

1. Remove dev credentials from the shipping config; add first-boot provisioning.
2. Complete the Pi kiosk Definition of Done plus a Pi 4 hardware checklist.
3. Implement the signed APT repo, signed checksums and per-image SBOM.
4. Write end-user docs (install / first boot / update / recovery / support).
5. Only then start the desktop ISO Core and Education editions
   (see `docs/EDITION-STRATEGY.md`).
