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
| 3 | **Server / pods** | image/ISO (cloud-init capable) + `qcow2` VM image; **now includes an Xfce desktop** (pods run on servers and need a GUI) | CIT + **customers (shipped)** |
| 4 | **Docker / pods** | container images (amd64 + arm64): headless **dev spaces** (devcontainers) **and** Xfce **remote-desktop** pods — see ADR-0005 | CIT + customers |

**Goal:** every visible surface is branded — bootloader/firmware where possible,
quiet boot, Plymouth splash, greeter/login, wallpaper, installer, MOTD/issue,
`/etc/os-release`, default hostname — from a **shared layer** so branding is
defined once.

**Desktop environment (ADR-0003):** **KDE Plasma** is the default desktop;
**Xfce** is used on the **server/pods** target.

**Mobile control (ADR-0004, accepted):** a **Flutter (Android)** app to control the
CIT-OS desktop/pods from a phone, using the **KDE Connect protocol (v8)** as the
transport (Dart `citos_connect` library; `citos-control` D-Bus service on the
desktop; headless `kcd` on pods); **LAN + internet**; **actions + full screen**;
parity target = **Microsoft Phone Link**. Fork/rebrand KDE Connect is **planned,
later**. Scoped in `docs/research/desktop-mobile-control.md`.

**Brand placeholders** (see ADR §7 Q3):
`Name = CIT-OS`, `id = citos`, `hostname = citos`, `support = https://cybroid.com`.
Still needed: **logo (SVG+PNG)** and **hex colours**. Placeholders live in
`common/branding/` until supplied.

---

## 2. Status dashboard

| Phase | Deliverable | Status |
|---|---|---|
| **1** | ADR: base distribution + repo/plan | **DONE** |
| **2** | Repo skeleton + Docker/WSL2/GCP dev environments | **DONE** |
| **3** | Working Pi image (arm64, Lite + Cage kiosk + Plymouth) + QEMU tests | TODO |
| **4** | `<brand>-base` package + signed APT repo + Docker/pod images (headless dev spaces + Xfce remote-desktop pods) | TODO |
| **5** | Server/pods image (Xfce DE + cloud-init + qcow2 + RDP/VNC) | TODO |
| **6** | Desktop installable ISO (KDE Plasma default + Xfce "Lite") | TODO |
| **7** | CI/CD pipeline + documentation + hardware release checklist | IN PROGRESS |
| **8** | Mobile desktop-control app (Flutter + KDE Connect transport) | TODO |

Done so far: repo + ADR + plan; **brand assets imported** from `novaoneltd/cit`
into `common/branding/`; **GitHub Actions** started (`ci.yml`, `nightly.yml`) and
running **inside a Debian 13 container** (matches the shipping base OS).

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

    phone (Flutter app, ADR-0004) ── LAN + internet ──▶ desktop/pods:
        KDE Connect protocol (kdeconnect-kde / headless `kcd`)
        + KRDP (full screen) + `citos-control` D-Bus service
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
  docker/          Dockerfiles for pod families (ADR-0005):
                     pod-base, pod-dev-<stack> (headless devcontainers),
                     pod-desktop (Xfce + xrdp/noVNC)
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

### Phase 2 — Repo skeleton + dev environments ✅ DONE
- [x] `git init`, `.gitignore`, `README.md`, this plan, `docs/adr/`
- [x] `/.devcontainer` (Debian Trixie) = canonical build environment
- [x] `tools/` baseline helper (`tools/preflight.sh` toolchain check)
- [x] Document WSL2 setup and the GCP x86 VM (8 vCPU / 32 GB) setup; mention
      **arm64 GCP VM** as the fast native path for Pi builds → `docs/dev-environments.md`
- [x] Make test tooling work with the Deepin box's **QEMU 8.2** (feature-detect
      which `-M` machines exist; never hard-code `raspi4b`) → documented in
      `docs/dev-environments.md` §6 (scripts land in Phase 3)
**Exit criteria:** any teammate can build inside the devcontainer; docs written.

### Phase 3 — Pi image v0 (Milestone A) 
- [ ] Choose Pi builder (follow-up ADR): `pi-gen` (x86-host friendly) vs
      `rpi-image-gen` (arm64 native, preferred if an arm64 host is available)
- [ ] arm64 **Lite** base + CIT branding (os-release, motd, issue, hostname)
- [ ] Quiet boot + **Plymouth** splash + CIT wallpaper
- [ ] **kiosk**: systemd service launching one fullscreen app, auto-restart on
      crash; **runtime swappable** — (a) Flutter via **flutter-pi** (direct
      DRM/KMS, no compositor) or (b) `cage` + Chromium (native `.deb`) web app.
      See `docs/research/kiosk-runtime.md` (ADR-0002 pending)
- [ ] Minimal "hello world" bundle per kiosk mode (Flutter bundle + web page)
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

### Phase 4 — Shared package + APT repo + Docker/pods
- [ ] Build `<brand>-base` `.deb` (branding assets, config, systemd units, defaults)
- [ ] Per-target meta-packages `<brand>-rpi`, `<brand>-desktop`, `<brand>-server`
- [ ] Signed APT repo (aptly or reprepro) + CI signing key (secrets only)
- [ ] Refactor the Pi image to consume the repo / install `<brand>-base`
- [ ] **Pod images (ADR-0005)** from `debian:trixie-slim`, amd64 + arm64:
  - [ ] `citos-pod-base` (branding + `kcd` + SSH + tooling, no desktop)
  - [ ] `citos-pod-dev-<stack>` headless **devcontainers** (`.devcontainer/devcontainer.json`
        + `devcontainer.metadata` label) — generic/Python/Node first
  - [ ] `citos-pod-desktop` (Xfce 4.20 + **xrdp** primary, **noVNC** fallback + `kcd`)
- [ ] Container smoke tests (docker/podman, buildx + QEMU binfmt)
**Exit criteria:** `<brand>-base` installs on a clean Trixie container and applies
branding; pod images (headless + desktop) pass smoke tests on both architectures.

### Phase 5 — Server / pods image
- [ ] Server image/ISO, **cloud-init capable**, **including an Xfce 4.20 desktop**
      (pods run on servers and need a GUI — ADR-0003)
- [ ] `qcow2` VM image
- [ ] Network remote-access path for the Xfce session: **RDP (xrdp) primary** with
      **VNC/noVNC fallback** — same config as `citos-pod-desktop` (ADR-0005) + branding
- [ ] Ship headless **`kcd`** for phone control on servers/pods (ADR-0004)
- [ ] x86_64 QEMU/KVM boot + smoke tests (session up, branding, os-release)
**Exit criteria:** qcow2 + ISO boot in KVM, show a branded Xfce session, and pass
the server smoke test.

### Phase 6 — Desktop ISO
- [ ] `live-build` installable hybrid ISO, x86_64 (arm64 optional); **Calamares** installer
- [ ] Desktop environment: **KDE Plasma 6.3** (default) with a **"Lite" Xfce 4.20**
      variant for low-spec hardware — see `docs/research/desktop-environment.md`
      (ADR-0003)
- [ ] Branded boot (GRUB/isolinux), installer, Plasma **global theme**, **SDDM**
      greeter, wallpaper; **KDE Kiosk** profiles for school machines
- [ ] Ship **KDE Connect + `krdp`** and the `citos-control` service for phone control
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

### Phase 8 — Mobile desktop-control app (Flutter + KDE Connect)
- [x] **ADR-0004 accepted**: Flutter (Android) client + **KDE Connect protocol v8**
      as transport; LAN + internet; actions + full screen; Phone Link parity;
      fork/rebrand KDE Connect later — see `docs/research/desktop-mobile-control.md`
- [ ] Desktop: ship `citos-control` D-Bus service + KDE Connect plugins; enable `krdp`
- [ ] Dart **`citos_connect`** package (discovery + TLS + pairing + packet/plugin layer)
- [ ] Phone app: branded CIT Flutter client; pairing/security over LAN; signed release
- [ ] Internet path: self-hosted relay/tunnel (WireGuard first) — ADR-0004 open item 1
- [ ] Pods: expose `kcd` (headless KDE Connect) so pods are controllable too (ADR-0005)
**Exit criteria:** a phone can control a CIT-OS desktop and a pod (actions +
optional full screen), on LAN and (with the relay) over the internet.

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
| 1 | Logo assets | imported from `novaoneltd/cit` | **done** |
| 2 | Palette confirmation (true primary; monochrome variant; wallpapers) | derived from logo SVG | **confirm with brand owner** |
| 3 | Pi builder: pi-gen vs rpi-image-gen | decide Phase 3 | open |
| 4 | APT repo tool: aptly vs reprepro | decide Phase 4 | open |
| 5 | Desktop installer: Calamares vs debian-installer | **Calamares** (Debian Live default) | leaning Calamares |
| 6 | Engineers' exact runtimes + path/package dependencies | Debian-compatible | re-confirm before Phase 6 |
| 7 | arm64 desktop ISO needed? | x86_64 first | open |
| 8 | Kiosk system-UI runtime | Flutter via `flutter-pi` (Pi) + GTK embedder (desktop) | **decision pending → ADR-0002** (see `docs/research/kiosk-runtime.md`) |
| 9 | Desktop environment | **KDE Plasma 6.3** (default) + Xfce 4.20 "Lite" variant | **DONE → ADR-0003** |
| 10 | Server/pods DE | **Xfce 4.20** | **DONE → ADR-0003** |
| 11 | Pod image variants (with/without desktop; dev space vs remote desktop) | base + per-stack headless devcontainers + Xfce remote-desktop pod | **DONE → ADR-0005** |
| 12 | Mobile app: phone OS (Android only vs iOS too), control scope (screen vs actions), network (LAN vs internet), build vs rebrand KDE Connect | **Flutter/Android + KDE Connect transport; LAN+internet; actions+full screen; Phone Link parity; rebrand later** | **DONE → ADR-0004** (see `docs/research/desktop-mobile-control.md`) |
| 13 | Remote-access protocol for server/pods Xfce (VNC vs RDP) | **RDP (xrdp) primary + VNC/noVNC fallback** | **DONE → ADR-0005** |
| 14 | Internet path for mobile control (relay/tunnel design) | WireGuard first | open → ADR-0004 follow-up |
| 15 | Which pod dev stacks to ship first | generic + Python + Node | open → ADR-0005 |

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
| 2026-10-11 | Imported CIT logo assets from `novaoneltd/cit` into `common/branding/`; added `brand.toml` (derived palette); started GitHub Actions (`ci.yml`, `nightly.yml`); CI platform confirmed = GitHub Actions. |
| 2026-10-11 | Fixed CI/base-OS mismatch: jobs now run inside a **`debian:13-slim` container** (was the Ubuntu runner host). Added `docs/research/kiosk-runtime.md` (flutter-pi feasibility: Pi 2/3/4 + Zero 2 supported, Pi 5 not; plugin caveats) and opened the kiosk-runtime decision (→ ADR-0002). |
| 2026-10-11 | Added `docs/research/desktop-environment.md`: recommends **KDE Plasma 6.3** for the desktop target (best branding hooks + KDE Kiosk lockdown), with an **Xfce 4.20 "Lite"** variant; Calamares installer. Opened the desktop-environment decision (→ ADR-0003); updated Phase 6. |
| 2026-10-11 | Owner decisions recorded in **ADR-0003 (accepted)**: KDE Plasma = default desktop; **Xfce for the server/pods target**; Calamares installer. Server/pods now ships a GUI (Phase 5). Added **`docs/research/desktop-mobile-control.md`** for a **customized KDE phone app** to control the desktop (KDE Connect + `krdp` + `citos-control`) and a new **Phase 8** (→ ADR-0004). Recorded `krdp 6.3.5` in Debian 13. |
| 2026-10-11 | **ADR-0004 accepted**: mobile client is a **Flutter (Android)** app with the **KDE Connect protocol (v8)** as transport (Dart `citos_connect`; `citos-control` on desktop; headless `kcd` on pods); **LAN + internet** (self-hosted relay); **actions + full screen**; parity target = **Phone Link**; fork/rebrand KDE Connect **later**. **ADR-0005 accepted**: pods ship as **headless dev spaces** (devcontainers) **and** **Xfce remote-desktop pods** (xrdp primary, noVNC fallback); remote-access choice resolved to RDP+VNC. Updated Phases 4/5/8, architecture, layout, and open items (added #14 relay, #15 dev stacks). |
| 2026-10-11 | **Phase 2 done**: added the canonical **`.devcontainer`** (Debian 13 Trixie build image + Docker socket mount), `docs/dev-environments.md` (devcontainer/WSL2/GCP x86+GCP arm64/Deepin-QEMU), and `tools/preflight.sh` (toolchain check, shellchecked in CI). CI now validates `devcontainer.json` and requires the new files. |
