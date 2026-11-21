# Cybroid Control Android app (v0 skeleton)

Flutter/Android UI skeleton for controlling Cybroid OS desktops and pods from a
phone. See [ADR-0004](../../../docs/adr/ADR-0004-mobile-client.md).

**Status: skeleton.** The device list is intentionally empty, the pairing screen
does not exchange keys, and every action in the grid returns
`status: unimplemented` from `cybroidos_connect`'s stub plugins. It does not yet
speak KDE Connect, and full-screen control is not implemented.

## What is wired

- Material 3 home screen with a discovered-device list, pairing screen and an
  actions grid (lock, open URL, notification, full screen).
- `cybroidos_connect` is consumed through a path dependency; action dispatch goes
  through its `PluginRegistry`.
- `INTERNET`, `ACCESS_NETWORK_STATE` and `WAKE_LOCK` permissions are declared,
  and cleartext traffic is disabled in the manifest.

## Build

Prerequisites: Flutter SDK (Android toolchain), Android SDK/Java 17, and a
`local.properties` file in `android/` pointing at the Flutter SDK (gitignored).

```sh
cd apps/mobile/cybroidos_control_app
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

Dart/Flutter compilation was not run in the packaging validation environment for
this change.

## Signing

No keystore or signing configuration is committed. For a release build, create a
keystore outside the repository and reference it from an untracked
`android/key.properties` plus a release signing block in
`android/app/build.gradle`, for example using `flutter build apk --release`.
Keep keystore passwords out of source control and out of CI logs. Play Store
publishing and signing are not part of this skeleton.

## Known limitations

- No KDE Connect transport, TLS pairing or interoperability test yet.
- No remote input, clipboard, notifications bridge, SMS/calls or photos.
- KRDP phone-client compatibility is unverified (upstream notes mixed results
  for Microsoft's Android RDP client; freeRDP-family clients have worked).
