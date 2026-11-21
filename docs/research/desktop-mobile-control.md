# Research: Mobile app to control the Cybroid OS desktop from a phone

- **Status:** **decided — see [ADR-0004 (accepted)](../adr/ADR-0004-mobile-client.md)**
  (Flutter/Android client + KDE Connect transport; LAN + internet; actions + full
  screen; Phone Link parity; rebrand later). This doc remains the option survey.
- **Date:** 2026-10-11
- **Related:** [PLAN](../PLAN.md), ADR-0003 (desktop environment), ADR-0004
- **Ask:** a **customized KDE app** that lets a phone **control the Cybroid OS
  desktop** remotely (owner's requirement).

## TL;DR recommendation

- **Desktop side:** ship **KDE Connect** (`kdeconnect-kde`) as the transport and
  the **`krdp`** RDP server (both are in Debian 13) for optional full-screen
  *view + control*. Add a small CIT daemon (`cybroidos-control`) exposing
  CIT-specific actions over D-Bus / KDE Connect commands.
- **Phone side:** build a **branded Kirigami (Qt/KDE) Android app** — the
  KDE-native answer to "customized KDE app". Reuse the KDE Connect protocol and
  plugins where possible instead of starting from scratch.
- **Caveat:** a mature, feature-complete **custom** phone app is a *new product*,
  not an OS tweak — it needs Android build tooling, signing, and its own release
  cycle. Scope and confirm requirements before committing.

## What "control the desktop" can mean (drives the design)

| Capability | Best KDE building block | Notes |
|---|---|---|
| Remote input (phone as touchpad/keyboard) | KDE Connect "Remote Input" plugin | already exists |
| Run actions (lock, shutdown, launch app, script) | KDE Connect "Run Commands" plugin | customizable commands |
| Media + clipboard + notifications + file/URL share | KDE Connect | already exists |
| Full screen **view + control** (see the plasma desktop) | **`krdp`** (RDP) + an RDP client on the phone | packaged in trixie |
| Push/mirror content, app launcher, workspace control | custom `cybroidos-control` D-Bus service | to build |

Most "control" asks are already covered by **KDE Connect**; full remote-screen
control is **KRDP**. A custom app mainly adds **branding** and **CIT-specific
commands / UX**.

## Building blocks (verified 2026-10-11)

- **KDE Connect** — multi-platform (Linux desktop; Android; iOS; Windows; macOS;
  Plasma Mobile). Features include remote input, run-commands, media remote,
  clipboard, notifications, file/URL share, "ring my phone". Phone↔desktop runs
  over the **local network** with TLS; plugin architecture on both sides (desktop
  and Android plugin READMEs). iOS port exists but with **known limitations**.
- **`krdp`** — *KDE's RDP Server with a settings module for Plasma*, **packaged in
  Debian 13 trixie (`6.3.5-1`)**. Lets standard RDP clients connect to a Plasma
  session. **Caveat to re-verify:** KRDP's own README historically listed
  *Microsoft's Remote Desktop client for Android* as **not working**, and freeRDP
  (`xfreerdp`/`wlfreeRDP`), Remmina and Thincast as working — confirm the current
  state before promising phone RDP.
- **Kirigami** — KDE's QtQuick UI framework; **officially supports Android** (and
  Plasma Mobile), shipping to Play/F-Droid. LGPL-2.0-or-later. This is the natural
  framework for a branded KDE phone app.
- **Flutter** (alternative phone stack) — the owner already prefers Flutter for
  the system UI; if a single cross-platform (Android **and** iOS) client matters
  more than KDE-native integration, Flutter may be the better client stack.

## Options

| Option | What it is | Pros | Cons |
|---|---|---|---|
| **A. Branded KDE Connect** | Fork/rebrand the Android KDE Connect app + add CIT plugins | fastest; battle-tested transport + plugins; matches "KDE app" | Android-focused; iOS port limited; forking upstream app = maintenance |
| **B. `krdp` + RDP client** | Enable KRDP on desktop; use a phone RDP client | full screen view+control; no custom app needed | client-compat caveats; heavier; not a bespoke "CIT app" |
| **C. Custom Kirigami client** | New KDE-native Android app (reusing KDE Connect protocol / D-Bus bridge) | fully branded; KDE-native | real product effort; Android toolchain; signing/release |
| **D. Flutter client** | Cross-platform phone app (Android+iOS) talking to a CIT desktop service | one codebase; owner likes Flutter; iOS coverage | not "KDE-native"; needs a desktop service/API |

## Recommendation in context

- **Phase 1 (low effort):** ship **KDE Connect + `krdp`** on the desktop and treat
  the stock KDE Connect phone app as the interim control tool. Ship a small
  **`cybroidos-control`** package (D-Bus service + KDE Connect "Run Commands" entries)
  for CIT actions.
- **Phase 2 (the "customized KDE app"):** build a **branded Kirigami Android app**
  on the KDE Connect protocol (Option A/C), OR a **Flutter** client (Option D) if
  cross-platform + one codebase is preferred. Decide in ADR-0004.
- **Pods/server (Xfce):** control via the same `cybroidos-control` + an Xfce-appropriate
  remote path (VNC/RDP); confirm with ADR-0003 open item 1.

## Open questions (need answers before ADR-0004)

1. **Phone OS:** Android only, or **iOS too**? (KDE Connect iOS and Kirigami both
   favour/limit Android; iOS pushes us toward Flutter.)
2. **Meaning of "control":** full remote screen (view+control) **and/or** app-level
   actions (launch, lock, shutdown, push content)? Determines KRDP vs KDE Connect
   vs custom service.
3. **Network scope:** **same LAN only** (KDE Connect's model), or **over the
   internet** (needs a relay/VPN; bigger security scope)?
4. **Build vs reuse:** rebrand/fork **KDE Connect**, or build a **new app** on its
   protocol? (Maintenance vs control.)
5. **Branding:** is the phone app in scope for Cybroid OS branding now or later?
6. **Do pods** (server/Xfce) also need phone control?

## Sources

- `kdeconnect.kde.org` (features, platforms) and `KDE/kdeconnect-kde` /
  `kdeconnect-android` READMEs (plugin architecture; remote input; run commands).
- `packages.debian.org` — `krdp` `6.3.5-1` in Debian 13 "trixie".
- `KDE/krdp` README (known-working RDP clients; caveats).
- `develop.kde.org` / `KDE/kirigami` (Android + Plasma Mobile support; LGPL).
