# Swapping the Cybroid OS kiosk app

The kiosk launcher is runtime-agnostic (ADR-0002). Selection happens in
`/etc/cybroidos/kiosk.conf`:

```sh
# Web app (default): cage + Chromium, fullscreen, ephemeral /run profile
MODE=cage-chromium

# Flutter app via flutter-pi
MODE=flutter

# Restart the runtime automatically after an unexpected exit
RESTART_ON_CRASH=1
```

## Web app

Edit `usr/share/cybroidos/kiosk/index.html` (rendered by
`tools/render-brand.py`) or replace it in the image overlay. Chromium is
deliberately launched without `--no-sandbox` and with an ephemeral
`--user-data-dir` under `/run/cybroidos`.

## Flutter app

1. Replace `apps/kiosk/flutter/lib/main.dart` with the production app.
2. Run `tools/build-kiosk-flutter.sh` (needs the Flutter SDK) or build a bundle
   manually for linux-arm64.
3. The bundle goes to
   `/usr/share/cybroidos/kiosk/flutter_bundle` and `flutter-pi` loads it.
4. `KIOSK_FLUTTER=1 targets/rpi/build.sh` does steps 2–3 automatically into a
   staged copy, keeping the repo clean.

## systemd supervision (optional)

The image also ships
`/etc/systemd/system/cybroidos-kiosk.service`, which runs the same launcher as
the `cybroid` user with `Restart=always` and hardening options. It is **not**
enabled by default because tty1 autologin already starts the launcher. To use
it instead:

```sh
# Stop tty1 autologin for the kiosk user, then:
systemctl enable --now cybroidos-kiosk.service
```

The launcher itself supervises the runtime with a short restart loop, so both
modes recover from a crash.

## Adding a third runtime

Add a new `case` branch in
`targets/rpi/stage-cybroidos/00-cybroidos/files/usr/bin/cybroidos-kiosk`,
document the `MODE` value in `kiosk.conf`, add dependencies to
`common/packages/cybroidos-kiosk/debian/control`, and update
`00-packages-nr`. Never launch a browser with `--no-sandbox`.
