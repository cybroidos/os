# cybroidos_connect (v0 skeleton)

Pure Dart building blocks for the KDE Connect **protocol v8** client used by the
Cybroid OS Android control app. See
[ADR-0004](../../../docs/adr/ADR-0004-mobile-client.md) for the product decision.

**Status: v0 skeleton, not a production-complete transport.** It is not yet
interoperability-tested against `kdeconnect-kde`, `kdeconnect-android` or the
headless `kcd` daemon. Do not rely on it for secure pairing yet.

## Protocol baseline

KDE Connect v8 packets are newline-terminated JSON objects with `id`, `type` and
`body` (plus optional `payloadSize` / `payloadTransferInfo`). LAN discovery uses
UDP broadcast on port 1716 and mDNS `_kdeconnect._udp`; TCP/1716 is upgraded to
TLS with self-signed certificates and SHA-256 pinning. These are the facts this
skeleton is built around; upstream protocol details are not a guaranteed
third-party interface and must be re-checked when tracking releases.

## Modules

| Module | State in 0.1.0 |
| --- | --- |
| `packet.dart` | Implemented: v8 envelope encode/decode, validation, newline stream decoder. |
| `tls.dart` | Implemented: SHA-256 pin helpers and per-device pin store. No `SecureSocket` wiring, no bundled keys or pins. |
| `discovery.dart` | UDP/1716 identity broadcast and identity parsing scaffolding. mDNS is an explicit `UnimplementedError` stub. |
| `pairing.dart` | Pairing state machine, PIN validation and pair packet builders. Key exchange, TOFU and peer verification are not implemented. |
| `plugin.dart` | Plugin registry and action routing; bundled action/full-screen plugins return `status: unimplemented`. |

## Development

```sh
dart pub get
dart test
```

Dart compilation/testing could not be run in the packaging validation
environment for this change; run the commands above in a Flutter/Dart SDK
environment before merging SDK-facing changes.

## Security notes

- No hardcoded certificates, pins, keys or passwords.
- Pin values are supplied by the caller; `PinStore.verify` fails closed when a
  device has no pins.
- Pairing never reports `paired` from `submitPin` alone; peer confirmation is a
  separate step that still needs implementation.
