# Cybroid OS

Branded operating-system images for **Cybroid** (Cybroid Technologies (U) Ltd) and
its customers, built from one repository and one build system.

Four targets are planned around one shared base and branding layer. The
**Raspberry Pi kiosk** is the first implemented target; the others are on the
roadmap.

| Target | Artefact | Status |
|---|---|---|
| Raspberry Pi | flashable `.img` → branded kiosk (develop/test on Pi 3; runs on Pi 4) | Implemented (`targets/rpi`) |
| Desktop | bootable, installable ISO — Cybroid school computers | Planned |
| Server | minimal cloud-init image + `qcow2` (ship to customers) | Planned |
| Docker | base container images (amd64 + arm64) | Planned |

- **Base OS:** Debian 13 "Trixie" — see [`docs/adr/ADR-0001-base-distribution.md`](docs/adr/ADR-0001-base-distribution.md)
- **Plan of record:** [`docs/PLAN.md`](docs/PLAN.md) (living document)
- **Project reports:** [end-user readiness](docs/END-USER-READINESS.md), [security posture](docs/SECURITY-POSTURE.md), [editions strategy](docs/EDITION-STRATEGY.md)
- **Guides:** [release checklist](docs/RELEASE-CHECKLIST.md), [security policy](docs/SECURITY.md), [APT repo](docs/APT-REPO.md), [user docs](docs/user/INSTALL.md)
- **Editions:** Core, Education, Developer, Professional, Enterprise — see [`editions/`](editions/README.md)

## Status

Early foundation. The base-distro ADR is accepted and the Raspberry Pi kiosk
target builds a branded image. Desktop, server and Docker are designed but not
yet implemented. See the status dashboard in `docs/PLAN.md`.

## Layout

```
common/     shared branding, config, systemd units, <brand>-base packaging
targets/    per-target builders/overlays — implemented: rpi (desktop/server/docker planned)
apt-repo/   signed Cybroid APT repository tooling
editions/   build-time feature flags per product edition
tests/      QEMU, container and real-hardware validation
ci/         CI helper scripts (workflows in .github/workflows; planned)
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
