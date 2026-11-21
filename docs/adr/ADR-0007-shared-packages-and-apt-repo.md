# ADR-0007: Shared layer as Debian packages + APT repo

- **Status:** Accepted (2026-10-11)
- **Date:** 2026-10-11
- **Deciders:** Cybroid OS maintainers (Cybroid Institute of Technology / CIT)
- **Related:** ADR-0001 (base distribution), ADR-0003/0005 (targets),
  `docs/PLAN.md` (Phase 4).

## 1. Context

The architecture (PLAN §4) puts the substantial logic in a **shared layer** so a
change to branding/config flows to every target through one package. Phase 4
builds that: a `<brand>-base` `.deb` (+ per-target meta-packages) and a **signed
APT repository**, then refactors the targets to consume them. PLAN open item #4
(aptly vs reprepro) is decided here.

## 2. Decision

**Packages** (built from `common/packages/`):

| Package | Role |
|---|---|
| `cybroidos-base` | identity (`os-release`), MOTD/issue, brand assets, shared config |
| `cybroidos-rpi` | Raspberry Pi meta-package (kiosk deps, Pi config) |
| `cybroidos-desktop` | desktop meta-package (KDE Plasma, SDDM, KDE Connect, `krdp`) |
| `cybroidos-server` | server/pods meta-package (Xfce, `kcd`, remote access) |
| `cybroidos-kiosk` | kiosk systemd unit + launcher (runtime-agnostic, ADR-0002) |

- **Version** is taken from `common/branding/brand.toml` (`identity.version`) so
  branding and package versions stay in lockstep.
- **`os-release` branding:** `cybroidos-base` ships `/usr/lib/os-release` and, in
  `preinst`, `dpkg-divert`s base-files' file
  (`--divert /usr/lib/os-release.base-files`), so the standard `/etc/os-release`
  symlink resolves to Cybroid OS content. `postrm` removes the diversion. This avoids
  a file conflict with the Essential `base-files` package.
- **APT repo:** **`reprepro`** — file-based, no long-running DB/daemon, easy to
  drive from CI and to sign (`Release.gpg`/`InRelease`). Published to GitHub
  Pages (or an object store) in Phase 4; signing key lives only in CI secrets.
- **Build/verify in CI:** packages build in a **`debian:13-slim`** container
  (matching the shipping base), are installed on a clean root to assert branding,
  and are linted. `tools/build-package.sh` renders branding from `brand.toml`
  before `dpkg-buildpackage`.

## 3. Consequences

**Positive**
- One place for branding/config; targets become thin overlays.
- `reprepro` needs no daemon and suits CI; signed repo is straightforward.
- Version lockstep with `brand.toml`.

**Negative / risks**
- `dpkg-divert` of `base-files` is a deliberate, documented deviation; verify it
  survives `base-files` upgrades (re-run of `preinst` is not automatic — the
  diversion persists, which is what we want).
- `reprepro` is less feature-rich than `aptly` for snapshots/mirrors; acceptable
  for our scale.
- The maintainer contact in `debian/control` is a **placeholder** until supplied.

## 4. Verification log

Debian packaging conventions (debhelper-compat 13, `Rules-Requires-Root: no`,
`3.0 (native)` source), `dpkg-divert` semantics for `/usr/lib/os-release`, and
`reprepro` signing behaviour are standard, documented Debian mechanisms. The
`cybroidos-base` package is verified in CI (build, `dpkg-deb -I/-c`, install on a
clean Trixie root, assert `/etc/os-release` `ID=cybroidos`, lintian).
