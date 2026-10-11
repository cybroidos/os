# CIT-OS

Branded operating-system images for **CIT** (Cybroid Institute of Technology) and
its customers, built from one repository and one build system.

Four targets, one shared base and branding layer:

| Target | Artefact |
|---|---|
| Raspberry Pi | flashable `.img` → branded kiosk (develop/test on Pi 3; runs on Pi 4) |
| Desktop | bootable, installable ISO — CIT school computers |
| Server | minimal cloud-init image + `qcow2` (ship to customers) |
| Docker | base container images (amd64 + arm64) |

- **Base OS:** Debian 13 "Trixie" — see [`docs/adr/ADR-0001-base-distribution.md`](docs/adr/ADR-0001-base-distribution.md)
- **Plan of record:** [`docs/PLAN.md`](docs/PLAN.md) (living document)

## Status

Early foundation. The base-distro ADR is accepted; the repo skeleton and build
environment are being set up. See the status dashboard in `docs/PLAN.md`.

## Layout

```
common/     shared branding, config, systemd units, <brand>-base packaging
targets/    per-target builders/overlays: rpi, desktop, server, docker
apt-repo/   signed CIT APT repository tooling
tests/      QEMU, container and real-hardware validation
ci/         CI helper scripts (workflows in .github/workflows)
tools/      helper scripts
docs/       guides + ADRs
```

## Building

Build environment is the devcontainer (or any Debian 13 host). Instructions land
with Phase 2 — see `docs/PLAN.md`.

## Contributing

This repository may be developed on a machine that can become read-only at any
time: **commit and push small, reviewable changes often.**

## Branding

Name `CIT-OS`, id `citos`, hostname `citos`, support `https://cybroid.com`.
Logo assets and palette live in [`common/branding/`](common/branding/) (imported
from the CIT web repo). Palette is derived from the logo and awaits brand-owner
confirmation — see `common/branding/README.md`.
