# CIT-OS — Development Plan

> Living document. **Update the status tables and checkboxes as work lands, and
> add an entry to §12 Change log every time you edit it.** This file is the single
> source of truth for "what are we doing and where are we".

- **Owner:** CIT-OS maintainers (Cybroid Institute of Technology)
- **Base OS decision:** [ADR-0001](adr/ADR-0001-base-distribution.md) — **Debian 13
  "Trixie"** for all targets; Raspberry Pi OS (Debian Trixie) lineage for the Pi.
- **Repository:** https://github.com/cybroidinstitute/cit-os
- **Last updated:** 2026-10-11

---

## 1. What CIT-OS is

One repository and one build system that produces **branded operating-system
images** for four targets, sharing as much configuration as possible.

| # | Target | Artefact | Who uses it |
|---|---|---|---|
| 1 | **Raspberry Pi** | flashable `.img` → branded kiosk | CIT labs / customers |
| 2 | **Desktop** | bootable, installable ISO (x86_64; arm64 optional) | **CIT school computers** (+ a few customers who choose CIT-OS over Windows) |
| 3 | **Server** | minimal image/ISO (cloud-init capable) + `qcow2` VM image | CIT + **customers (shipped)** |
| 4 | **Docker** | base container images (amd64 + arm64) | CIT + customers |

**Goal:** every visible surface is branded — bootloader/firmware where possible,
quiet boot, Plymouth splash, greeter/login, wallpaper, installer, MOTD/issue,
`/etc/os-release`, default hostname — from a **shared layer** so branding is
defined once.

**Brand placeholders** (see ADR §7 Q3):
`Name = CIT-OS`, `id = citos`, `hostname = citos`, `support = https://cybroid.com`.
Still needed: **logo (SVG+PNG)** and **hex colours**. Placeholders live in
`common/branding/` until supplied.

---

## 2. Status dashboard

| Phase | Deliverable | Status |
|---|---|---|
| **1** | ADR: base distribution + repo/plan | **DONE** |
| **2** | Repo skeleton + Docker/WSL2/GCP dev environments | **IN PROGRESS** |
| **3** | Working Pi image (arm64, Lite + Cage kiosk + Plymouth) + QEMU tests | TODO |
| **4** | `<brand>-base` package + signed APT repo + Docker target | TODO |
| **5** | Server image (minimal + cloud-init + qcow2) | TODO |
| **6** | Desktop installable ISO | TODO |
| **7** | CI/CD pipeline + documentation + hardware release checklist | TODO |

**Milestone A (fast path):** the engineer is ready to flash an SD card now, and
will flash the stock Raspberry Pi OS image **today**, then switch to CIT-OS when
it exists. So Phase 3's first output is a **minimal, bootable, branded Pi image**
as early as possible, even before the shared package/APT repo work.

---

## 3. Ground rules / constraints

1. **Prefer official, maintained tooling** over custom scripts. State the versions
   we build against.
2. **No manual steps, no secrets in the repo.** Reproducible and scriptable only.
3. **Never modify the engineers' current environment.** Everything new lives in
   this repo and is adoptable incrementally.
4. **Be honest about emulation.** QEMU is *not* a Pi. Anything about camera, GPIO,
   real display, firmware splash or touch must be validated on real hardware and
   labelled as such. QEMU has **no `raspi5`** model and its `raspi4b` model has
   **no Ethernet** (missing GENET) and a known keyboard-input bug; QEMU 8.2 on the
   Deepin box has **no `raspi4b` at all** (only `raspi0/1/2/3`).
5. Keep QEMU-only workarounds in a **test profile**, never in the shipping image.
6. **Commit and push often.** The build PC may become read-only at any time.

---

## 4. Architecture at a glance

```
                    common/  (branding, config, systemd units, <brand>-base .deb)
                       │
        ┌──────────────┼───────────────┬───────────────┬───────────────┐
        ▼              ▼               ▼               ▼               ▼
   targets/rpi    targets/desktop  targets/server  targets/docker   default/
   (pi-gen or      (live-build      (cloud image    (debian:         (branding
    rpi-image-gen)  ISO)             + chroot,        trixie-slim)     values)
                                     qcow2)
        │              │               │               │
        └──────────────┴───────┬───────┴───────────────┘
                               ▼
                    signed CIT APT repo (aptly/reprepro)
                    <brand>-base, <brand>-rpi, <brand>-desktop, <brand>-server,
                    <brand>-kiosk, cit tooling
```

Images **only install packages and apply thin per-target overlays**. The
substantial logic lives in the shared `.deb` packages, so a change to branding or
config flows to every target through one package.

---

## 5. Repository layout (proposed)

```
/common            Shared layer
  branding/        logo, colours, wallpaper, plymouth theme, grub/isolinux art
  packages/        Debian packaging for <brand>-base and per-target meta-packages
  config/          os-release, motd, issue, hostname, sysctl, ssh defaults
  systemd/         shared units (kiosk, branding)
/targets
  rpi/             pi-gen / rpi-image-gen stages + overlays
  desktop/         live-build config (branded boot + installer + desktop)
  server/          cloud-image customization, qcow2 build
  docker/          Dockerfiles (amd64 + arm64)
/apt-repo          aptly/reprepro config + signing + publish tooling
/tests
  qemu/            headless Pi boot test + graphical virt test
  container/       docker/podman smoke tests
  checklists/      real-hardware validation checklist (Pi 4)
/ci                CI helper scripts; workflows live in .github/workflows/
/tools             helper scripts (versioning, image resize, dtb extraction)
/docs              README, build guide, "add a package", "swap the kiosk app",
                   "add a hardware target", ADRs, this PLAN
/.devcontainer      VS Code devcontainer = the canonical build environment
```

Justification: `common/` holds everything shared so branding/config is defined
once; `targets/*` holds only thin, target-specific overlays and builder config;
`tests/` and `ci/` are separate so the shipping image never contains test-only
hacks; `docs/` and `adr/` keep decisions discoverable.

---

## 6. Phase plan

### Phase 1 — Foundation & base-distro decision ✅ DONE
- [x] Base-distro ADR with verified versions and a recommendation → `docs/adr/ADR-0001-base-distribution.md`
- [x] This development plan
**Exit criteria:** decision recorded; plan agreed.

### Phase 2 — Repo skeleton + dev environments ⬅ IN PROGRESS
- [ ] `git init`, `.gitignore`, `README.md`, this plan, `docs/adr/`
- [ ] `/.devcontainer` (Debian Trixie) = canonical build environment
- [ ] `tools/` baseline helpers
- [ ] Document WSL2 setup and the GCP x86 VM (8 vCPU / 32 GB) setup; mention
      **arm64 GCP VM** as the fast native path for Pi builds
- [ ] Make test tooling work with the Deepin box's **QEMU 8.2** (feature-detect
      which `-M` machines exist; never hard-code `raspi4b`)
**Exit criteria:** any teammate can build inside the devcontainer; docs written.

### Phase 3 — Pi image v0 (Milestone A) 
- [ ] Choose Pi builder (follow-up ADR): `pi-gen` (x86-host friendly) vs
      `rpi-image-gen` (arm64 native, preferred if an arm64 host is available)
- [ ] arm64 **Lite** base + CIT branding (os-release, motd, issue, hostname)
- [ ] Quiet boot + **Plymouth** splash + CIT wallpaper
- [ ] **kiosk**: systemd service running a single fullscreen app under **cage**,
      auto-restart on crash; Chromium (native `.deb`) web app; swappable
- [ ] Native hello-world (Qt/GTK) as a second, swappable example
- [ ] QEMU test scripts:
  - [ ] headless boot: `qemu-system-aarch64 -M raspi3b`, **resized power-of-two
        copy**, kernel+DTB extracted from the built image, serial console
  - [ ] graphical: `-M virt` + virtio-gpu + generic arm64 kernel/initramfs
        **injected into a COPY of the image** (never the release image),
        `WLR_RENDERER=pixman` (cage) + Chromium `--disable-gpu`, GTK/VNC display;
        verify Plymouth + kiosk launch + logo
**Exit criteria:** `cit-os-<ver>-rpi-arm64.img` boots in QEMU (raspi3b) and shows
the branded kiosk; flashable image available for the engineer. *Real-hardware
validation deferred to the Phase 7 checklist.*

### Phase 4 — Shared package + APT repo + Docker
- [ ] Build `<brand>-base` `.deb` (branding assets, config, systemd units, defaults)
- [ ] Per-target meta-packages `<brand>-rpi`, `<brand>-desktop`, `<brand>-server`
- [ ] Signed APT repo (aptly or reprepro) + CI signing key (secrets only)
- [ ] Refactor the Pi image to consume the repo / install `<brand>-base`
- [ ] Docker target from `debian:trixie-slim` (amd64 + arm64) with the same packages
- [ ] Container smoke tests (docker/podman, buildx + QEMU binfmt)
**Exit criteria:** `<brand>-base` installs on a clean Trixie container and applies
branding; Docker images pass smoke tests on both architectures.

### Phase 5 — Server image
- [ ] Minimal server image/ISO, **cloud-init capable**
- [ ] `qcow2` VM image
- [ ] x86_64 QEMU/KVM boot + smoke tests (services up, branding, os-release)
**Exit criteria:** qcow2 + ISO boot in KVM and pass the server smoke test.

### Phase 6 — Desktop ISO
- [ ] `live-build` installable hybrid ISO, x86_64 (arm64 optional)
- [ ] Branded boot (GRUB/isolinux), installer, desktop, greeter, wallpaper
- [ ] QEMU/KVM boot + smoke tests
**Exit criteria:** ISO installs and boots to a branded desktop; smoke test passes.

### Phase 7 — CI/CD, docs, release checklist
- [ ] CI pipeline (GitHub Actions) building all targets, running smoke tests,
      versioning artefacts, publishing images + packages; caching; **nightly build**
- [ ] Docs: README, build guide, "how to add a package", "how to swap the kiosk
      app", "how to add a new hardware target"
- [ ] Real-hardware checklist for the Pi 4 (firmware splash, `config.txt`, real
      display, touch, GPIO, boot from SD/SSD) — **release points only**
**Exit criteria:** green pipeline producing versioned, published artefacts.

---

## 7. Test strategy (summary)

| Level | What | Where |
|---|---|---|
| Pi headless boot | kernel+DTB from image, serial console, resized copy | QEMU `-M raspi3b` |
| Pi graphical | Plymouth + kiosk + logo, software rendering, GTK/VNC | QEMU `-M virt` + virtio-gpu |
| Desktop/server | ISO + qcow2 boot, service/branding/os-release smoke tests | QEMU/KVM x86 |
| Container | build + run smoke tests both architectures | docker/podman + buildx/binfmt |
| Real hardware | firmware splash, config.txt, display, touch, GPIO, SD/SSD boot | **Pi 4 — release points only** |

QEMU-only workarounds are confined to a **test profile**. Emulation success is
**never** reported as hardware validation.

---

## 8. CI/CD

- **Platform:** GitHub Actions (default; revisitable).
- **Stages:** build all targets → run smoke tests → version artefacts → publish
  (GitHub Releases for images, GHCR for containers) → APT repo publish.
- **Caching:** apt/mmdebstrap caches, Docker layer cache.
- **Nightly:** scheduled build + repo refresh; security-fix rebuilds.
- **Secrets:** signing key + registry tokens in CI secrets only.

---

## 9. Development environments

- **Windows main machine:** build via the **devcontainer** in Docker Desktop (WSL2
  backend). No native Windows build.
- **WSL2:** instructions for running the devcontainer / builds directly.
- **GCP x86 VM (8 vCPU, 32 GB):** full builds for desktop/server/Docker and the
  Pi image (slower, cross/QEMU). **arm64 VM (e.g. Tau T2A)** is the fast native
  path for Pi builds.
- **Deepin laptop (QEMU 8.2):** runs the test scripts locally; scripts
  feature-detect available machines (`raspi3b`, `raspi4b`) and adapt.

---

## 10. Open items / questions

| # | Item | Default | Status |
|---|---|---|---|
| 1 | Logo (SVG+PNG) + hex colours | placeholder palette | **NEEDED** |
| 2 | Pi builder: pi-gen vs rpi-image-gen | decide Phase 3 | open |
| 3 | APT repo tool: aptly vs reprepro | decide Phase 4 | open |
| 4 | Desktop installer: Calamares vs debian-installer | Phase 6 | open |
| 5 | Engineers' exact runtimes + path/package dependencies | Debian-compatible | re-confirm before Phase 6 |
| 6 | arm64 desktop ISO needed? | x86_64 first | open |

---

## 11. Definition of done (per image)

- [ ] Boots on the target (or its QEMU proxy) with no manual steps
- [ ] All visible surfaces branded (boot/splash/login/desktop/motd/os-release)
- [ ] Reproducible from a clean checkout + CI
- [ ] Smoke tests pass and are wired into CI
- [ ] Real-hardware checklist completed at release points (where applicable)

---

## 12. Change log

| Date | Change |
|---|---|
| 2026-10-11 | Initial plan; ADR-0001 accepted (Debian 13 Trixie; Pi dev/test on Pi 3, target Pi 4). |
