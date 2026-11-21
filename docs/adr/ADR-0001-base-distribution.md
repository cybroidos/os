# ADR-0001: Base distribution for the Cybroid OS image family

- **Status:** Accepted (2026-10-11) — base = Debian 13 "Trixie" for all targets;
  Pi dev/test on Pi 3, images must also run on Pi 4. A few items in §7 remain open.
- **Date:** 2026-10-11
- **Deciders:** Cybroid OS maintainers (Cybroid Technologies (U) Ltd)
- **Supersedes:** none

## 1. Context

Cybroid OS is one repository/build system that must produce branded images for four
targets while sharing as much configuration as possible:

| Target | Artefact | Required |
|---|---|---|
| Raspberry Pi | flashable `.img`, boots to a branded Cage/Chromium kiosk | Pi 4 required; Pi 3 and Pi 5 desirable |
| Desktop | bootable, installable ISO (x86_64; arm64 optional) with branded boot/installer/desktop | yes |
| Server | minimal image/ISO, cloud-init capable, plus a `qcow2` VM image | yes |
| Docker | base container images (amd64 + arm64) with the same branded base packages/config | yes |

Hard constraints from the brief:

- Raspberry Pi must be **first-class**: kernel, firmware, camera, GPIO, hardware
  video and the display stack must work with minimal workarounds.
- One base that covers Pi + desktop + server + Docker **without fragmentation**.
- Must **not disrupt the engineers' current workflow** (toolchain, package names,
  paths).
- Everything reproducible and scriptable; no manual steps; no secrets in the repo.
- Branding must cover bootloader/firmware (where possible), quiet boot, Plymouth,
  greeter/login, wallpaper, installer, MOTD/issue, `/etc/os-release`, hostname.

This ADR decides the **single base distribution family**. All per-target tooling
choices (pi-gen vs rpi-image-gen, live-build, etc.) depend on it and are recorded
in follow-up ADRs.

## 2. Decision drivers

1. Pi 4/5 support quality (kernel, firmware, camera, GPIO, video, display).
2. Chromium availability for a Cage/Chromium kiosk — must be buildable and
   reproducible into an image offline, not fetched from a live store at runtime.
3. One base for desktop/server/Docker without splitting the package namespace.
4. Package freshness and LTS length.
5. Build tooling maturity per target.
6. Licensing / trademark rules for rebranding.
7. Update strategy.
8. Engineering-workflow compatibility (the binding constraint — see §7 Q1).

## 3. Options considered

- **A. Debian 13 "Trixie" as the single base**, using the Raspberry Pi OS
  (Debian Trixie + Raspberry Pi board-support) lineage for the Pi target.
- **B. Ubuntu 26.04 LTS everywhere.**
- **C. Hybrid: Debian for Pi + server + Docker, Ubuntu LTS for desktop.**

### Verified facts (checked against official sources on 2026-10-11)

| Component | Verified value | Source |
|---|---|---|
| Debian stable | 13 "trixie", point release 13.7 (2026-09-12); full support to 2028-08-09, LTS to 2030-06-30 | debian.org/releases |
| Debian oldstable | 12 "bookworm", LTS to 2028-06-30 | debian.org/releases |
| Raspberry Pi OS | Debian **13 (trixie)**, kernel **6.18**, released 2026-09-15; boards incl. 3B/4B/5/CM5; Lite ≈516 MB | raspberrypi.com/software/operating-systems |
| Ubuntu LTS | 26.04 "Resolute Raccoon", released 2026-04-23, kernel **7.0**, supported to Apr 2031 (ESM 10 yr) | ubuntu release notes / Phoronix |
| Chromium on Debian | native `.deb` `chromium` 153.0.8010.52-1~deb13u1, built for amd64 + arm64 + armhf | packages.debian.org/trixie/chromium |
| Chromium on Ubuntu | `chromium-browser` is a **transitional package to the snap** (`1snap1-0ubuntu4` on 26.04); no Chromium deb | packages.ubuntu.com, ubuntu.com blog |
| cage (Wayland kiosk compositor) | `0.2.0-2` packaged in Debian trixie (in Debian since bullseye) | packages.debian.org/trixie/cage |
| Plymouth | packaged in Debian trixie | packages.debian.org/trixie/plymouth |
| Pi image builder (official) | `rpi-image-gen` (BSD-3; mmdebstrap + genimage; best on an arm64 Pi host, QEMU "not formally supported") | github.com/raspberrypi/rpi-image-gen |
| Pi image builder (official, legacy) | `pi-gen`, `RELEASE` default `trixie`; Debian host; Docker build is only partial isolation (needs privileged, binfmt, loop devices) | github.com/RPi-Distro/pi-gen |
| Desktop ISO tooling | Debian `live-build` (used for official Debian live ISOs on trixie) | live-team.pages.debian.net |
| Server/VM | official Debian cloud images (qcow2/raw, cloud-init) for trixie amd64 + arm64 | cloud.debian.org/images |
| QEMU Pi emulation | only `raspi0/1/2/3/4` — **no `raspi5`**; `raspi4b` **lacks GENET Ethernet + PCIe** and has a known keyboard-input bug; **QEMU 8.2 ships no `raspi4b`** (only raspi0/1/2/3) | qemu.org/docs/system/arm/raspi |
| Ubuntu on Pi — camera | works since 25.04, but `picamera2` is PPA-only (not in archive); IMX500 firmware **cannot ship in Ubuntu (licensing)**; Hailo unsupported | ubuntu.com/hardware/docs |
| Trademark — Canonical | redistribution of **modified** Ubuntu must be certified/approved by Canonical or you must **remove the marks and recompile** | canonical IPRights policy |
| Trademark — Raspberry Pi | logo requires a licence; attribution "Raspberry Pi is a trademark of Raspberry Pi Ltd" required; derivatives via pi-gen explicitly supported | raspberrypi.com/trademark-rules, /licensing |

## 4. Evaluation

### 4.1 Raspberry Pi 4/5 support quality — **A wins**

Raspberry Pi's kernel, bootloader/firmware (EEPROM), `libcamera`/`rpicam-apps`,
`picamera2`, GPIO (`libgpiod`/`lgpio`), `raspi-config`, `rpi-eeprom` and the
hardware video/decode stack are **first-party and only first-class on the
Raspberry Pi OS (Debian) lineage**. Ubuntu on Pi has caught up materially for the
camera since 25.04, but has concrete gaps today: `picamera2` is only in a PPA, the
IMX500 AI-camera firmware is **excluded from Ubuntu for licensing reasons**, the
Hailo accelerator is unsupported, and GPU/graphics acceleration on Pi 5 has a
history of lagging. For an IoT/embedded-education OS that must actually drive
sensors, cameras and GPIO in student labs, this is the decisive factor. Choosing
Debian does **not** abandon the Raspberry Pi lineage — Raspberry Pi OS *is Debian
Trixie*, so using it is the mainstream, best-supported path.

### 4.2 Chromium for a Cage/Chromium kiosk — **A wins decisively**

Debian ships a **native, sandboxed Chromium `.deb`** (currently 153.x) for
amd64/arm64/armhf that can be baked into an image with `apt`, with **no network
dependency at boot** and no reliance on a running store daemon. Ubuntu ships
Chromium **only as a snap**; the apt package is a transitional stub that installs
the snap. For a kiosk this is a real problem: it forces `snapd` into the image,
pulls the browser from the Snap Store at install/first-run (breaking offline and
reproducible image builds), complicates confinement/`~/.config` handling, and adds
a well-known moving part to a device that boots-but-must-never-blank. Cage itself
is packaged for Debian trixie, so the whole Wayland-kiosk chain is `apt`-native.

### 4.3 One base, no fragmentation — **A wins**

Debian gives one package namespace and one mental model for all four targets:
`pi-gen`/`rpi-image-gen` (Pi), `live-build` (desktop ISO), official cloud images +
chroot (server/`qcow2`), and `debian:trixie-slim` (Docker). Ubuntu forces a
different toolchain (livecd-rootfs/subiquity, snap seeding) and would make Pi the
odd one out. Option C keeps two bases forever and doubles maintenance; it is only
justified if the engineers' desktop workflow is locked to Ubuntu (see §7 Q1).

### 4.4 Package freshness & LTS length — **slight edge B**

Ubuntu 26.04 LTS (kernel 7.0) is newer than Raspberry Pi OS/Debian Trixie
(kernel 6.18) and offers 5 yr standard + 5 yr ESM. Debian Trixie offers 3 yr +
2 yr LTS (to 2030). Since **we rebuild and re-ship images ourselves**, the
practical LTS value is lower than the raw numbers suggest; fresher packages are a
nice-to-have, not a driver. This is the one axis where Ubuntu is genuinely ahead,
and it does not outweigh 4.1–4.3.

### 4.5 Build tooling per target — **A wins**

All four targets have **official, maintained Debian tooling** today. The Pi tools
are explicit about Debian hosts. Ubuntu ISO construction is the least
scriptable/reproducible of the set.

### 4.6 Licensing & rebranding — **A wins**

Debian's trademark position is friendly to derivatives (source is free; you simply
don't call the result "Debian"). Canonical's IPRights policy requires that any
*modified* Ubuntu either be certified by Canonical or have the marks removed
**and source recompiled** to create your own binaries — a heavier legal/process
burden for exactly what we are doing (rebranding). Raspberry Pi marks only require
that we not use their logo without a licence and that we attribute the trademark;
we will strip Pi-branded artwork from our images and keep the board-support
packages (which retain their own licences). Net: Debian is the lowest-friction
base to rebrand into Cybroid OS.

### 4.7 Update strategy — **tie**

Both base on signed archives with security teams. Either way Cybroid OS adds its own
signed APT repo (aptly/reprepro) for `<brand>-*` packages and a nightly rebuild.
Debian's model (security + LTS) is well understood and matches the Pi lineage.

### 4.8 Workflow compatibility — **conditional, decisive**

The brief makes "do not disrupt the engineers" binding. If Cybroid engineers live in
Ubuntu toolchains, Option A can still be made low-friction because Debian and
Ubuntu share `.deb`/APT/`/usr` conventions, but we must confirm the actual stack
before committing (see §7 Q1). This is the single question that could flip the
recommendation.

## 5. Decision

**Adopt Option A: a single base of Debian 13 "Trixie" for all four targets.**

- **Pi target:** build on the **Raspberry Pi OS (Debian Trixie) lineage** — i.e.
  Debian Trixie plus the first-party Raspberry Pi kernel/firmware/board-support
  packages — via an official builder (`rpi-image-gen` or `pi-gen`; choose in a
  follow-up ADR). This is Debian, not a second distro.
- **Desktop:** Debian `live-build` installable hybrid ISO.
- **Server:** official Debian Trixie cloud image/host + chroot customization;
  ship `qcow2` + a cloud-init-capable minimal ISO.
- **Docker:** `debian:trixie-slim` base, multi-arch.
- Shared layer: `<brand>-base` `.deb` + per-target meta-packages, served from our
  own signed APT repo.

This is **conditional** on §7 Q1 (engineers' current workflow). If the answer
shows a hard dependency on Ubuntu-only tooling on the desktop/server side, the
fallback is Option C (Ubuntu for desktop/server only) — but the Pi target stays on
Debian/Raspberry Pi OS regardless, because of 4.1 and 4.2.

## 6. Consequences

**Positive**
- Pi hardware (camera/GPIO/video/display) works with upstream support, not
  workarounds.
- Native Chromium `.deb` on every target → offline, reproducible kiosk images.
- One package namespace and one set of build tools across all four targets.
- Lowest trademark friction for rebranding.
- `mmdebstrap`/`debootstrap`/`live-build`/cloud images are all scriptable and CI-
  friendly, satisfying the "no manual steps" rule.

**Negative / risks**
- Slightly older userspace than Ubuntu 26.04 (kernel 6.18 vs 7.0). Mitigation:
  track `trixie-backports` where it matters; our nightly rebuild keeps security
  current.
- Raspberry Pi's `rpi-image-gen` prefers an **arm64 Pi host** and only
  "informally" supports QEMU/x86 hosts. Mitigation: support both `pi-gen`
  (x86-host-friendly, Debian host) and `rpi-image-gen` (arm64), and document the
  arm64 GCP VM path for fast native Pi builds.
- QEMU cannot fully emulate a Pi 5 and its `raspi4b` model lacks networking. This
  limits automated Pi testing — a real-hardware release checklist is mandatory,
  and emulation results must never be claimed as hardware validation.
- Debian points releases/renames packages over time; we pin and test.

**Out of scope for this ADR:** the specific Pi builder, ISO/installer choice
(Calamares vs debian-installer), the kiosk app runtime, and the APT repo tool.

## 7. Resolved decisions

**Q1 — Engineering workflow (mandated question). — PARTIALLY OPEN.**
No engineer has started on Cybroid OS yet; the immediate plan is that an engineer
flashes the stock Raspberry Pi OS image to an SD card today, and switches to the
Cybroid OS image once it is ready. Decisions taken:
  - Build the OS on a **Debian-compatible `.deb`/APT** model regardless (the target
    images are Debian-based either way).
  - Keep the existing `cit` CLI / VS Code extension installed independently
    (npm / extension), **not** by renaming or colliding with it. Our OS id is
    `cybroidos`, so there is no path clash with `/usr/bin/cit`.
  - Re-confirm the engineers' exact languages/runtimes and any hard package-name
    or absolute-path dependencies before the desktop ISO phase.

**Q2 — Redistribution scope. — ANSWERED.** Cybroid OS is for **Cybroid and its customers**:
  - **Server images** → shipped to customers.
  - **Desktop** → **Cybroid school computers** (primary use), with a few customers who
    may choose Cybroid OS over Windows.
  - Therefore the base is **redistributable**, so we **strip all upstream brand
    marks** (Ubuntu / Raspberry Pi OS / Raspberry Pi logos) and rely on package
    licences. A "Powered by Raspberry Pi" trademark licence is optional and only
    needed if we later want to show the Pi logo on our own packaging.

**Q3 — Brand.** Name = **Cybroid OS**; OS `id` = **cybroidos**; default hostname
**cybroid**; support URL **https://cybroid.com**. **Still needed:** logo (SVG + PNG)
and primary/secondary hex colours. *Until provided:* a placeholder logo and a
deep-navy/blue palette live in `common/branding/`.

**Q4 — CI/CD. — ANSWERED.** **GitHub Actions** (repo is on GitHub under the
`cybroidtech` org). Pipeline started in `.github/workflows/` (`ci.yml`
validation now; build jobs added per phase; `nightly.yml` scheduled).

**Q3 (assets) — PARTIALLY ANSWERED.** Logo assets were taken from the existing
**`novaoneltd/cit`** web repository and placed in `common/branding/logo/`
(`cybroid-logo.svg`, `cybroid-logo.png`, `cybroid-mark.png`, `cybroid-icon-64.png`,
`cybroid-favicon.png`). Palette in `common/branding/brand.toml` is derived from the
logo SVG gradients (`#557fc0` → `#69cce1` over navy `#112649` / `#0e2044`) and is
a **v0 default pending brand-owner confirmation** (monochrome variant, true
primary, wallpaper art).

**Q5 — Pi scope. — ANSWERED.** Develop and test on **Pi 3** (the reliable QEMU
model, `raspi3b`), but ship **one arm64 image that also runs on Pi 4**. Raspberry
Pi OS images are model-agnostic: the firmware selects the correct kernel/DTB at
boot, so a single image boots Pi 3, Pi 4 and (with current Trixie) Pi 5. Pi 5
validation comes later; QEMU has no `raspi5` model.

**Q6 — Default kiosk content.** *Default kept:* a Cybroid **web** hello-world page in
Chromium; a native (Qt/GTK) hello-world shipped as a swappable second example.

**Q7 — Publication.** *Default kept for now:* GitHub Releases (private repo) for
images + GitHub Container Registry for Docker; revisit if customers need a CDN.

**Q8 — Signing.** *Default kept:* generate a Cybroid APT signing key and store it
**only** in CI secrets (never in the repo).

### Own APT repository — confirmed

Yes, Cybroid OS needs its **own signed APT repository**. It will carry our own
packages: `<brand>-base`, the per-target meta-packages (`<brand>-rpi`,
`<brand>-desktop`, `<brand>-server`), the kiosk service and app packages, and any
future `cit`-branded tooling we choose to package as `.deb`. Reasons: our packages
are not in any upstream archive; images must install them reproducibly and
offline; upgrades and nightly rebuilds need a stable signed origin; and the
`<brand>-base` layer is the mechanism that keeps branding/config identical across
all four targets. Tool choice (aptly vs reprepro) is a follow-up ADR.

## 8. Verification log

All versions above were checked against official sources on 2026-10-11
(debian.org/releases, raspberrypi.com/software/operating-systems,
ubuntu.com release notes, packages.debian.org, packages.ubuntu.com, qemu.org ARM
system docs, canonical.com/legal, raspberrypi.com/trademark-rules). Nothing in
this ADR is asserted from memory alone. Claims about *unemulated* Pi behaviour
(camera, GPIO, real display, firmware splash) are explicitly marked as requiring
real-hardware validation.
