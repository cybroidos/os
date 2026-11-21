# ADR-0002: Kiosk / system-UI runtime

- **Status:** Accepted (2026-10-11)
- **Date:** 2026-10-11
- **Deciders:** Cybroid OS maintainers (Cybroid Technologies (U) Ltd)
- **Related:** ADR-0001 (base distribution), ADR-0006 (Pi image builder),
  `docs/research/kiosk-runtime.md`, `docs/PLAN.md` (Phase 3).

## 1. Context

The Pi target boots into a **kiosk / system UI**. The owner **prefers Flutter**.
We need one runtime decision that covers the Pi (no desktop environment) and the
desktop target, while keeping the kiosk **swappable**.

Feasibility was researched in `docs/research/kiosk-runtime.md` (flutter-pi:
boards, DRM/KMS, plugins, build tooling, performance, risks).

## 2. Decision

- **Framework:** **Flutter** — one Dart codebase for the system UI across the Pi
  and desktop targets.
- **Pi kiosk runtime (primary):** **`flutter-pi`** — a Flutter *engine embedder*
  rendering **directly to DRM/KMS with no X11/Wayland compositor** (MIT; latest
  `release/1.1.1`, 31 Jan 2026).
- **Web fallback (secondary):** **`cage` + Chromium** (native `.deb`) remains a
  **swappable** second mode so a pure web app can drive the same kiosk. The
  systemd kiosk unit is **runtime-agnostic**: it launches *either* a Flutter bundle
  *or* Chromium.
- **Desktop target:** the **official Flutter GTK embedder** (`flutter build
  linux`), not kiosk mode.

## 3. Consequences

**Positive**
- Flutter everywhere; one codebase, per-target build (`flutterpi_tool build
  --arch=arm64 --cpu=pi4` bundle vs `flutter build linux`).
- No compositor on the Pi → lighter, faster boot to a fullscreen UI.
- First-class Pi peripheral plugins (`flutter_gpiod` GPIO, `linux_serial`,
  `linux_spidev`, ALSA audio, GStreamer video) suit Cybroid lab hardware.
- Chromium fallback keeps the kiosk app replaceable with a web app.

**Negative / risks**
- **Plugin coverage caveat:** any native plugin flutter-pi does not implement
  (camera, Bluetooth, secure storage, …) needs a bridge. *Confirm the kiosk app's
  actual plugin list before finalising the app.*
- **Pi 5 not supported** by flutter-pi; our shipping Pi target is **Pi 4**
  (supported). Revisit only if Pi 5 becomes a requirement.
- **Engine-version pinning:** flutter-pi needs engine binaries matching **Flutter
  stable** (`ardera/flutter-engine-binaries-for-arm`); pin the SDK in CI.
- **Touch latency:** the stock Pi touchscreen driver polls ~25 Hz; evaluate
  `ardera/raspberrypi-fast-ts` if the kiosk is touch-driven.
- **Bus factor:** flutter-pi is a single-maintainer community project (MIT,
  active). Mitigation: the kiosk service is runtime-agnostic, so we can switch to
  the GTK embedder or Sony `flutter-embedded-linux`.

## 4. Verification log

Facts from `ardera/flutter-pi` README + releases: boards = Pi 2/3/4 + Zero 2 (W),
**not** Pi 5 / Zero(1) / Pi 1; KMS + DRI required; plugins implemented
(`video_player`/GStreamer, `audioplayers`/ALSA, raw keyboard, text input,
`flutter_gpiod`, `linux_serial`, `linux_spidev`, partial `sentry_flutter`); build
via `flutterpi_tool`; engine binaries from `ardera/flutter-engine-binaries-for-arm`;
50–60 fps on Pi 4. `cage 0.2.0` and Chromium `.deb` confirmed in Debian 13.
Nothing asserted from memory alone. Hardware validation is deferred to the Phase 7
checklist.
