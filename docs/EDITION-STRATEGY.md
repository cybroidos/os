# Cybroid OS editions strategy

Date: 2026-11-21
Ask: Windows-style product editions (Home / Pro / Enterprise / Education),
adapted to Cybroid OS, achievable with the current repo and a small team.

## Proposed editions

| Edition | Audience | Included | Excluded / notes |
|---|---|---|---|
| **Core** | schools, labs, kiosks, general users | Debian base, branded boot/desktop, kiosk, signed updates, community support | No proprietary components, no paid support |
| **Education** | schools and labs | Core + classroom/kiosk management, offline content pack, restricted app install, teacher controls, managed update window | No SSH by default, no admin rights for pupils |
| **Developer** | engineers | Core + devcontainers, SDKs, Docker, git, pubkey-only SSH, optional local Kubernetes | No kiosk lockdown, no classroom management |
| **Professional** | individuals and offices | Core + KDE desktop, office suite, RDP/VNC remote access, optional Hangar add-on, paid support | Proprietary add-ons opt-in with a EULA |
| **Enterprise / Security** | organisations | Professional + Secure Boot, signed images, full-disk encryption, no autologin, MDM, audit logging, CVE SLA, SBOM per release | Requires management infrastructure |
| **Lite** | low-spec (~2 GB) machines | Xfce 4.20 variant of Core/Education (ADR-0003) | A variant, not a separate product line |

Rationale: one build system, one base package, edition overlays. It mirrors the
Windows edition ladder while keeping the open core free and putting value in
management, support and security — the Red Hat / Zorin model already recorded
in `docs/LICENSING.md`.

## How to implement with the current repo

The hooks already exist:

- `common/packages/cybroidos-base/` — one shared identity package.
- ADR-0007 names meta-packages (`cybroidos-base`, `cybroidos-rpi`,
  `cybroidos-desktop`, `cybroidos-server`, `cybroidos-kiosk`); add one per
  edition: `cybroidos-core`, `cybroidos-education`, `cybroidos-developer`,
  `cybroidos-professional`, `cybroidos-enterprise`.
- `brand.toml` is the single identity source; add an `[editions]` table for
  edition names and IDs.
- `tools/build-package.sh` and `tools/release-manifest.sh` are reusable;
  extend the manifest with an `edition:` field.

Recommended layout:

```
editions/
  core/config              # build-time flags common to all targets
  core/files/              # optional overlay
  education/config
  developer/config
  professional/config
  enterprise/config
```

**Select at build time, not runtime:** `targets/<target>/build.sh --edition
education`. Immutable images can then be signed individually, each with its own
SBOM.

Feature flags, with defaults per edition in `editions/<name>/config`:

- `ENABLE_KIOSK_MODE`, `ENABLE_CLASSROOM_TOOLS`, `ENABLE_DEVCONTAINERS`
- `ENABLE_REMOTE_DESKTOP`, `INCLUDE_PROPRIETARY`, `ENABLE_FDE`, `ENABLE_MDM`
- Security-sensitive flags default to OFF.

CI: matrix of target × edition; artifacts named
`cybroid-os-<edition>-<target>-<version>.<ext>`, each with signed checksums and
a release manifest.

Licensing: GPL code and CC BY-NC artwork apply to every edition; proprietary
add-ons only in Professional/Enterprise via `INCLUDE_PROPRIETARY=1`, registered
in `docs/PROPRIETARY-COMPONENTS.md`; the trademark policy requires derivatives
to de-brand.

## Roadmap for a small team

- **Phase A (now):** finish the Pi kiosk; ship **Core** and an **Education**
  pilot only. Fix every P0 security item. Complete the Definition of Done and
  Pi 4 hardware signoff.
- **Phase B:** desktop ISO Core + Education with Calamares; signed APT repo
  live; end-user documentation.
- **Phase C:** Developer and Professional editions plus pod images — ADR-0005's
  dev-space and remote-desktop pods map directly onto these editions.
- **Phase D:** Enterprise/Security with Secure Boot, FDE, MDM and a support SLA.

Do not launch all editions at once. Prove the base, the update channel and the
support process with one edition, then add the next.

## Decisions needed from the owner

1. Final edition names and which editions are paid.
2. Which editions may include proprietary components (Hangar today).
3. Support / SLA commitments per edition.
4. Brand-owner sign-off on the palette, wallpaper and trademark wording.
5. Target hardware list for validation (Pi 3/4, x86 desktops, pod hosts).
