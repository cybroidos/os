# Cybroid OS

Branded operating-system images for **Cybroid** (Cybroid Technologies (U) Ltd) and
its customers, built from one repository and one build system.

All four targets are implemented around one shared base and branding layer.
Build scripts and smoke tests exist for every target; hardware, QEMU/KVM and
signed-repository validation are still pending (see `docs/PLAN.md`).

| Target | Artefact | Status |
|---|---|---|
| Raspberry Pi | flashable `.img` → branded kiosk (Pi 3/4) | `targets/rpi` — Pi 4 hardware signoff pending |
| Desktop | installable hybrid ISO — KDE Plasma + Xfce "Lite" | `targets/desktop` — QEMU validation pending |
| Server | cloud-init image + `qcow2`, Xfce over RDP/noVNC | `targets/server` — QEMU validation pending |
| Docker | pod images (amd64 + arm64): base, dev stacks, Xfce desktop | `targets/docker` — smoke tests pending |

Phase 8 adds the mobile-control stack: the `cybroidos-control` D-Bus service,
the `cybroidos_connect` Dart package, an Android client skeleton and a
WireGuard relay v0 (`common/packages/cybroidos-control/`, `apps/mobile/`).

- **Base OS:** Debian 13 "Trixie" — see [`docs/adr/ADR-0001-base-distribution.md`](docs/adr/ADR-0001-base-distribution.md)
- **Plan of record:** [`docs/PLAN.md`](docs/PLAN.md) (living document)
- **Project reports:** [end-user readiness](docs/END-USER-READINESS.md), [security posture](docs/SECURITY-POSTURE.md), [editions strategy](docs/EDITION-STRATEGY.md)
- **Guides:** [build guide](docs/BUILD-GUIDE.md), [release checklist](docs/RELEASE-CHECKLIST.md), [security policy](docs/SECURITY.md), [APT repo](docs/APT-REPO.md), [user docs](docs/user/INSTALL.md), [add a package](docs/ADD-PACKAGE.md), [swap the kiosk app](docs/SWAP-KIOSK-APP.md), [add a hardware target](docs/ADD-HARDWARE-TARGET.md)
- **Editions:** Core, Education, Developer, Professional, Enterprise — see [`editions/`](editions/README.md)

## Status

All phases have buildable scaffolding. The Pi image, desktop ISO, server
qcow2, Docker pods and shared packages are defined in one repository with a
single branding source. Real-hardware signoff, QEMU/KVM smoke runs, deployment
of the signed APT repository and KDE Connect interoperability remain before a
public release. GitHub Actions was blocked by account billing at the time of
writing; local syntax/render/manifest checks pass. See the status dashboard in
`docs/PLAN.md`.

## Layout

```
common/     shared branding, config, systemd units and cybroidos-* packages
targets/    per-target builders: rpi, desktop, server, docker
apps/       kiosk Flutter shell and mobile-control client/protocol package
apt-repo/   signed Cybroid APT repository tooling
editions/   build-time feature flags per product edition
tests/      qemu, desktop, server, container smoke tests + checklists
ci/         CI helper scripts (workflows in .github/workflows)
tools/      helper scripts (brand rendering, packaging, release manifests)
docs/       guides + ADRs
```

## Building

Build environment is the devcontainer (or any Debian 13 host).

```sh
# Shared branding package
tools/build-package.sh cybroidos-base

# Raspberry Pi kiosk image with a chosen edition
EDITION=core targets/rpi/build.sh
EDITION=education targets/rpi/build.sh

# Release manifest (optionally signed with GPG_KEY)
tools/release-manifest.sh --edition core targets/rpi/deploy out/manifest-core.md
```

See `docs/PLAN.md` for the full roadmap and `docs/RELEASE-CHECKLIST.md` for the
release gate.

## Licensing

The build system is free software under **GPL-3.0-or-later** ([`LICENSE`](LICENSE)).
Brand artwork is **CC BY-NC 4.0** ([`LICENSE-ASSETS`](LICENSE-ASSETS)). The Cybroid /
Cybroid names and logos are trademarks with a de-branding policy for derivatives
([`NOTICE.md`](NOTICE.md)). See [`docs/LICENSING.md`](docs/LICENSING.md) for the
rationale and [`docs/PROPRIETARY-COMPONENTS.md`](docs/PROPRIETARY-COMPONENTS.md)
for the register of non-free components (kept out of the public image).

## Contributing

This repository may be developed on a machine that can become read-only at any
time: **commit and push small, reviewable changes often.**

## Branding

Name `Cybroid OS`, id `cybroidos`, hostname `cybroid`, support `https://cybroid.com`.
Logo assets and palette live in [`common/branding/`](common/branding/) (imported
from the Cybroid web repo). Palette is derived from the logo and awaits brand-owner
confirmation — see `common/branding/README.md`.
