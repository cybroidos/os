# Research: Kiosk / system-UI runtime

- **Status:** **decided — see [ADR-0002 (accepted)](../adr/ADR-0002-kiosk-runtime.md)**
  (Flutter via `flutter-pi` primary; `cage`+Chromium swappable fallback;
  official GTK embedder on desktop). This doc remains the feasibility research.
- **Date:** 2026-10-11
- **Related:** [PLAN §6 Phase 3](../PLAN.md), ADR-0001 (Debian 13 Trixie), ADR-0002
- **Question:** which runtime renders the Cybroid OS kiosk / system UI on the Pi and
  desktop targets? The owner prefers **Flutter**; confirm feasibility and pick the
  embedder.

## TL;DR recommendation

- **Framework:** **Flutter** for the system UI / kiosk app (Dart, one codebase
  across Pi + desktop).
- **Pi kiosk runtime:** **`flutter-pi`** — a lightweight Flutter *engine embedder*
  that renders directly to **DRM/KMS with no X11/Wayland compositor**. Purpose-built
  for the Pi, cross-built from our x86/arm64 dev hosts, and it ships native plugins
  for the peripherals we care about (GPIO, serial, SPI, audio, video).
- **Desktop runtime:** the **official Flutter GTK embedder** (`flutter build linux`),
  which is what the desktop target already provides.
- **Retain a web mode:** `cage` + **Chromium** (native `.deb`) stays as the
  *swappable* second mode, so a pure web app can still drive the kiosk. The kiosk
  service is designed to launch **either** a Flutter bundle **or** Chromium.

## Candidates

| Runtime | Backend | Compositor needed | Plugin support | Fit |
|---|---|---|---|---|
| **flutter-pi** | DRM/KMS + GLES (direct) | **no** | good for Pi peripherals; gaps elsewhere | **Pi kiosk (primary)** |
| **Sony `flutter-embedded-linux`** | DRM/GBM, Wayland, X11 | no (DRM/GBM) | has its own plugin repo (video, camera) | alternative Pi/embedded |
| **Official Flutter GTK embedder** | Wayland/X11 | **yes** (e.g. `cage`) | full (same as desktop plugins) | **desktop**; heavier on Pi |
| **`cage` + Chromium** (non-Flutter) | Wayland/pixman | yes (cage) | n/a (web) | web-app mode / fallback |
| Qt/GTK native (non-Flutter) | Wayland/X11 | yes | n/a | minimal reference only |

## flutter-pi — findings (verified 2026-10-11)

Source: `ardera/flutter-pi` README + releases.

- **What it is:** a light-weight Flutter Engine embedder for Raspberry Pi. Runs
  *without X11* — you boot to the console, no desktop environment. Renders via
  DRM/KMS + hardware 3D (V3D). **MIT** licensed.
- **Latest release:** `release/1.1.1` (31 Jan 2026) — adds DRM-fd support and a
  **Raspberry Pi 5 cursor fix** (#506).
- **Boards:** README "known working" = **Pi 2, 3, 4** (incl. 512 MB) and
  **Pi Zero 2 (W)**. Explicitly **not** Pi Zero (1st gen) / Pi 1. **Pi 5 is not in
  the supported list** (a cursor fix exists, but it is not claimed supported) —
  our shipping Pi target is **Pi 4**, which is supported.
- **Requirements:** kernel-modesetting (KMS) + DRI (hardware 3D accel);
  CPU in ARMv7/ARMv8/x86/x86_64; must boot to **console** (no X11/Wayland owning
  the display); **Fake KMS**/V3D driver; GPU memory ≥ 64 MB; render-group access
  (or run as root). OpenGL ES via mesa is the tested path.
- **Plugins (this is the key caveat):** *pure Dart packages always work*; native
  **plugins need their platform side**. flutter-pi already implements:
  - `video_player` (GStreamer backend) and `flutterpi_gstreamer_video_player`
  - `audioplayers` ^5.0.0 (ALSA; **remove `pulseaudio`**, install `gstreamer1.0-alsa`)
  - raw keyboard, text input, mouse/touch
  - **`flutter_gpiod`** (GPIO via kernel interface), **`linux_serial`**,
    **`linux_spidev`** — directly useful for Cybroid lab hardware
  - partial `sentry_flutter`
  Any other plugin (e.g. **camera**, bluetooth, secure storage) must have a bridge
  written or be provided another way — see open risks.
- **Build/deploy:** dev machine (x86 or arm64) builds the bundle with
  **`flutterpi_tool`** (`flutter pub global activate flutterpi_tool`), e.g.
  `flutterpi_tool build --arch=arm64 --cpu=pi4 --release`, then `rsync` the bundle
  to the Pi and run `flutter-pi --release <bundle>`. Engine binaries come from
  `ardera/flutter-engine-binaries-for-arm` (pinned to Flutter stable). They can't
  be built *on* the Pi.
- **Performance:** author reports smooth **50–60 fps** on Pi 4 (2 GB) and Pi 3 A+
  for the Flutter SDK catalog examples.
- **Touch latency caveat:** the Raspberry Pi kernel touchscreen driver has a known
  poll bug (~25 Hz), making touch feel laggy. The author provides a userspace
  driver, `ardera/raspberrypi-fast-ts`, that fixes it. Relevant if our kiosk is
  touch-driven.

## Alternatives

- **Sony `flutter-embedded-linux`** — embedder with DRM/GBM, **Wayland** and X11
  backends, arm64 + x64, cross-compiles from x64; has a plugin repo
  (`flutter-elinux-plugins`, incl. video/camera). A credible alternative if
  flutter-pi's plugin gaps bite or if we need a Wayland-based Flutter target.
  *Not yet deeply verified — do before switching.*
- **Official Flutter GTK embedder** — `flutter build linux`; needs a Wayland/X
  compositor (`cage`) on the Pi. Full plugin support (matches desktop), but the
  GTK stack is heavier and works against our "lightweight kiosk" goal on the Pi.
  This is the natural choice for the **desktop** target.
- **`cage` + Chromium** — the classic web kiosk; already planned and stays as the
  web-app mode. `cage` 0.2.0 and Chromium `.deb` are both in Trixie.

## Recommendation in context

- **Pi kiosk:** `flutter-pi` as the default native runtime (direct DRM, no
  compositor, first-class Pi peripherals), with `cage`+Chromium kept as the
  swappable web mode. Both are launched by the same systemd kiosk unit.
- **Desktop:** official Flutter GTK embedder.
- **Shared:** one Flutter codebase; per-target build (`--cpu=pi4` bundle vs
  `flutter build linux`).

## Open risks / must verify on hardware

1. **Plugin coverage** — any native plugin not implemented by flutter-pi (camera,
   bluetooth, secure storage, …) needs a bridge. **Confirm the kiosk app's actual
   plugin list before locking this in.**
2. **Pi 5** — not in flutter-pi's supported list; our target is Pi 4. Revisit only
   if Pi 5 becomes a requirement.
3. **Touch latency** — plan to evaluate `raspberrypi-fast-ts`.
4. **Engine version pinning** — flutter-pi needs engine binaries matching Flutter
   *stable*; pin the Flutter SDK + engine version in CI.
5. **Bus factor** — flutter-pi is a single-maintainer community project (MIT,
   active: latest release Jan 2026). Mitigation: it is small and replaceable by the
   GTK embedder or `flutter-embedded-linux`; keep the kiosk service runtime-agnostic.
6. **Real-hardware validation** — FPS, touch, GPU memory, display — Phase 7
   checklist, not QEMU.

## Sources

- `ardera/flutter-pi` — README and releases (`release/1.1.1`, 31 Jan 2026).
- `ardera/flutterpi_tool`, `ardera/flutter-engine-binaries-for-arm`,
  `ardera/raspberrypi-fast-ts` (author's companion repos).
- `SONY/flutter-embedded-linux` + `flutter-elinux-plugins` (to verify).
