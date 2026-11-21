# Mobile desktop control — end-to-end overview (Phase 8, v0 skeleton)

This phase implements the first cut of [ADR-0004: Mobile client](../adr/ADR-0004-mobile-client.md),
informed by [the desktop/mobile control research](../research/desktop-mobile-control.md).
The goal is a Flutter/Android client that controls Cybroid OS desktops and pods
using KDE Connect protocol v8 over LAN, with an internet path via a self-hosted
WireGuard relay, and Phone Link parity as a longer-term roadmap.

Everything shipped here is a **v0 skeleton**: interfaces, scaffolding and stubs
are in place, but no end-to-end KDE Connect interoperability test has been run.

## Components

| Component | Path | Role | Status |
| --- | --- | --- | --- |
| Desktop service | `common/packages/cybroidos-control/` | D-Bus/CLI service (`com.cybroidos.Control`) for lock, URL/app launch, notifications, device info and KRDP full screen. | Action API implemented; session/KRDP integration needs validation. |
| Dart transport library | `apps/mobile/cybroidos_connect/` | Pure Dart KDE Connect v8 packet envelope, UDP discovery scaffold, TLS pin helpers, pairing interface and plugin registry. | Packet layer + pin helpers implemented; TLS/pairing/mDNS/plugin backends are stubs. |
| Android app | `apps/mobile/cybroidos_control_app/` | Flutter UI: device list, pairing screen, actions grid. | UI wired to stub methods; no transport yet. |
| Internet relay | `apps/mobile/relay/` | WireGuard provisioning sketch (phone → WireGuard → relay → LAN device). | Config generator only; keys/firewall/routing are operator-managed. |

Desktop ISOs are expected to pull `cybroidos-control` and `krdp`; pod images run
headless `kcd` with the same desktop service where actions are needed. KDE
Connect rebranding/forking remains explicitly deferred per ADR-0004.

## Build order

1. **Desktop service:** `tools/build-package.sh cybroidos-control` produces the
   `.deb` in `dist/`. Review `/usr/share/cybroidos/control/actions.json`, the
   D-Bus policy and the session environment notes before enabling the unit.
2. **Dart library:** `cd apps/mobile/cybroidos_connect && dart pub get && dart test`.
   The packet tests exercise the v8 envelope; they do not test a live peer.
3. **Android app:** `cd apps/mobile/cybroidos_control_app && flutter pub get &&
   flutter analyze && flutter build apk --debug`. Release signing is
   operator-managed; no keystore is committed.
4. **Relay (optional, internet path):** `apps/mobile/relay/setup-relay.sh
   ./generated`, then configure firewall, port forwarding and routing manually.

Dart/Flutter toolchains are not available in the packaging validation
environment for this phase, so steps 2–3 must be run in an SDK environment.

## Explicit limitations

- No real KDE Connect interoperability test yet (neither `kdeconnect-kde` nor
  headless `kcd` has been exercised against the Dart packet/discovery code).
- TLS trust is pins-only in helpers; no `SecureSocket` handshake, TOFU flow or
  key exchange is implemented. No keys or pins are bundled.
- Pairing UI validates a 6-digit PIN locally but sends nothing and verifies no
  peer certificate.
- Full-screen action assumes a KRDP user systemd unit and needs verification
  against the installed KRDP packaging and an Android RDP client.
- Internet relay needs operator-generated keys, a public endpoint, firewall and
  LAN routing; KDE Connect discovery does not cross subnets unaided.
- Phone Link parity items (messages, calls, photos, clipboard, media, DND,
  remote input) are roadmap only and are not implemented here.
- No Play Store signing or release pipeline is included.
