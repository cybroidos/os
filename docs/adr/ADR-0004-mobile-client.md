# ADR-0004: Mobile client to control CIT-OS desktops and pods

- **Status:** Accepted (2026-10-11)
- **Date:** 2026-10-11
- **Deciders:** CIT-OS maintainers (Cybroid Institute of Technology / CIT)
- **Related:** ADR-0003 (desktop environment), `docs/research/desktop-mobile-control.md`,
  ADR-0005 (pod image variants).

## 1. Context

CIT wants a **customized app that controls the CIT-OS desktop from a mobile
phone**. Owner's direction (2026-10-11):

- **Phone OS: Android.**
- **Build it in Flutter** (preferred), with **KDE Connect wrapped as the
  transport layer**.
- **Network: both** — same LAN *and* over the internet.
- **Control: both** — app-level actions *and* full-screen view/control.
- Ambition: match the functionality Windows offers with **Phone Link** ("Link to
  Windows"): notifications, messages, calls, photos, apps, clipboard, media,
  screen mirroring, etc.
- **Forking and rebranding KDE Connect** is acceptable but **comes later** (it is
  planned, not part of this first cut).

## 2. Decision drivers

1. The owner prefers **Flutter** for UI across the project.
2. Reuse a **proven, secure transport** (KDE Connect) rather than inventing one.
3. Must work on **LAN and over the internet**.
4. Must cover **both** command/action control and **full remote screen**.
5. Aim for **Phone Link feature parity**.
6. Keep the door open to **rebranding KDE Connect later**.

## 3. Verified facts (2026-10-11)

KDE Connect protocol (from `kdeconnect-meta` `protocol.md`, generated from JSON
Schemas — the doc notes it is *not* a formal third-party interface):

- **Packets:** newline-terminated JSON (`id`, `type`, `body`; optional
  `payloadSize` / `payloadTransferInfo` for file transfers) — JSON-RPC-like.
- **Discovery (LAN):** **UDP broadcast on port 1716** and **mDNS**
  (`_kdeconnect._udp`); identity packets carry `deviceId`, `protocolVersion`
  (current **v8**), `tcpPort`.
- **Transport:** TCP on **1716**, upgraded to **TLS**; file-transfer side
  channels on **1739–1764**. Pairing is **TOFU** with self-signed certs and
  **SHA-256 fingerprint** verification.
- **Architecture:** a UI-agnostic **core** exposing **D-Bus**, with independent
  **plugins** on each side (desktop + Android). Official implementations:
  Linux, Android, iOS (iOS limited).
- **Third-party reimplementations exist** — incl. **`kcd`, a headless Go
  implementation of KDE Connect v8** that works in **servers/containers** with no
  GUI/DBus, and Rust/Cosmic ports — proving the protocol can be reimplemented.

Phone Link feature set (for parity): notifications (view/pin/dismiss/reply), SMS
(send/reply, group, media), calls (make/receive/history/contacts), photos (recent
camera roll + drag/drop + **OCR text extraction**), mobile apps (select OEMs),
clipboard sync, media/audio control, **Do Not Disturb**, **Instant Hotspot**,
**screen mirroring**, ring/find phone, wallpaper, battery; reverse direction (lock
PC, send files, view clipboard). Works ideally on the same Wi-Fi, optionally via
cellular for remote.

Flutter today has **no first-party KDE Connect package**; a Dart implementation
must be written (the JSON schemas + Go/Rust ports are the reference).

## 4. Options considered

| Option | Transport | UI | Notes |
|---|---|---|---|
| **A. Flutter app + Dart KDE Connect implementation** | KDE Connect protocol v8, reimplemented in Dart | Flutter | owner's preference; interoperates with real KDE Connect; we own the stack |
| **B. Flutter app + embedded KDE Connect Android core** | native kdeconnect-android via platform channel | Flutter | reuses mature transport, but couples us to a Java module |
| **C. Branded Kirigami (Qt/KDE) app** | KDE Connect | Kirigami | most "KDE-native"; not Flutter |
| **D. Fork/rebrand KDE Connect Android wholesale** | KDE Connect | KDE Connect UI | fastest to "branded", least custom control |

## 5. Decision

1. **Client:** a **Flutter (Android-first)** app — the CIT control client.
2. **Transport:** the **KDE Connect protocol v8**, wrapped behind a Dart library
   **`citos_connect`** (packages: discovery, TLS, pairing, packet/plugin layer).
   This keeps the wire protocol KDE-Connect-compatible (so stock KDE Connect and
   `kcd` interoperate).
   - **Fallback** if a Dart reimplementation proves too costly: **Option B** —
     embed the Android KDE Connect core via a Flutter plugin (platform channel),
     keep the Flutter UI.
3. **Desktop/pod side:** ship **`kdeconnect-kde`** (+ `krdp` for full screen) on
   the desktop, and **`kcd`** (headless) on server/pod images; add a
   **`citos-control`** D-Bus/CLI service exposing CIT-specific actions (lock,
   shutdown, launch, push content, open lab/kiosk session).
4. **Network:** **LAN first** (KDE Connect UDP/mDNS + TLS). **Over-the-internet**
   via a **self-hosted relay/tunnel** (e.g. WireGuard or a small rendezvous+relay
   service) — KDE Connect has no NAT traversal of its own. Security scope defined
   in a follow-up.
5. **Control:** **both** — actions via KDE Connect plugins + `citos-control`, and
   **full screen** via **KRDP/RDP** (desktop) / VNC (pods).
6. **Parity target:** match the **Phone Link** feature list in §3 as the roadmap
   (messages, calls, notifications, photos, clipboard, media, DND, screen
   mirroring, find phone, battery).
7. **Later (planned):** fork/rebrand **KDE Connect** for deeper control and/or to
   own the transport; explicitly deferred.

## 6. Consequences

**Positive**
- One Flutter codebase for the phone client; matches the owner's preferences.
- Reuses a battle-tested, TLS-secured protocol; stays interoperable with KDE
  Connect and `kcd`.
- Same transport serves desktop (Plasma) and pods (headless `kcd`).
- Clear path to Phone Link parity.

**Negative / risks**
- **Reimplementing KDE Connect in Dart is real work** and the protocol is
  **not a guaranteed third-party interface** — we must track upstream changes and
  clean-room the pairing/TLS details carefully.
- **Internet control** needs a relay/VPN and a privacy/security design — a larger
  scope than LAN.
- **Calls/SMS/screen-mirroring** require deep Android integration (Telecom, SMS
  roles, screen capture) — some need special Android APIs/permissions.
- iOS is **out of scope** for now (Android-only, per owner); revisit later.

**Out of scope:** the desktop DE (ADR-0003), pod image variants (ADR-0005), and
the kiosk runtime (ADR-0002).

## 7. Open questions

| # | Question | Default until answered |
|---|---|---|
| 1 | Self-hosted relay design for internet (WireGuard mesh vs rendezvous+relay) | WireGuard-based first |
| 2 | Do we need SMS/calls (Telecom integration) in v1, or notifications/messages later? | Notifications + messages first; calls later |
| 3 | Screen mirroring: use KRDP/RDP, or an Android `MediaProjection`-based phone→PC path? | KRDP for desktop; scrcpy-style later |
| 4 | Reuse the KDE Connect device UI/branding or fully custom CIT UX? | Custom CIT UX over the shared transport |

## 8. Verification log

Protocol facts checked against `kdeconnect-meta` `protocol.md` (UDP 1716 + mDNS
discovery, TCP 1716 + TLS, ports 1739–1764, protocol v8, TOFU/SHA-256), the
`kcd` headless Go implementation (server/container, v8), and `kdeconnect-kde`
core/D-Bus/plugin architecture. Phone Link feature list checked against
Microsoft's official pages and CNET/ZDNet coverage. `krdp 6.3.5` confirmed
packaged in Debian 13. Nothing asserted from memory alone.
