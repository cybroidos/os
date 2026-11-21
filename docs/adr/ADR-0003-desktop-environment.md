# ADR-0003: Desktop environment across the Cybroid OS image family

- **Status:** Accepted (2026-10-11) — **KDE Plasma** is the default desktop;
  **Xfce** is used on the **server/pods** target; **Calamares** is the installer.
  A few items in §7 remain open.
- **Date:** 2026-10-11
- **Deciders:** Cybroid OS maintainers (Cybroid Institute of Technology / CIT)
- **Supersedes:** the "desktop environment" and "installer" parts of ADR-0001 §5
  and PLAN open items 5 and 9.
- **Related:** `docs/research/desktop-environment.md`,
  `docs/research/desktop-mobile-control.md`.

## 1. Context

The desktop target (CIT school computers + a few customers who choose Cybroid OS
over Windows) needs a branded, manageable desktop. Separately, the **server/pods**
target is now expected to **also feature a desktop environment** (the pods run on
servers and need a GUI reachable over the network). The owner's direction:

- **KDE Plasma** = the default desktop environment.
- **Xfce** = the desktop for the **server/pods** target (lightweight, server-side).
- Additionally, CIT wants a **customized KDE application to control the desktop
  from a mobile phone** (scoped in `docs/research/desktop-mobile-control.md`).

ADR-0001 fixed the base (Debian 13 "Trixie") but deliberately left the desktop
environment and installer open. This ADR closes those, and records the pods DE.

## 2. Decision drivers

1. Branding depth — every visible surface must be branded from `common/branding/`.
2. Manageability/lockdown for **shared school machines**.
3. Footprint — the desktop target and the (server) pods have different budgets.
4. Familiarity for users migrating from Windows.
5. Debian-native packaging; no snap/third-party-store dependency.
6. Ability to integrate a phone-based remote-control app.

## 3. Options considered

| DE | Version in Debian 13 "Trixie" | Session | Branding hooks | Lockdown | Footprint |
|---|---|---|---|---|---|
| **KDE Plasma** | **6.3.x** (Qt 6.8.2, KDE Frameworks 6.13) | Wayland (default) + X11 | global theme, **SDDM** theme, splash, wallpaper | **KDE Kiosk** (per user/group) | high (4 GB+) |
| **Xfce** | **4.20** | X11 (Wayland experimental) | GTK theme, **LightDM**/SDDM | limited | low (2 GB) |
| GNOME | 48 | Wayland (default) | gsettings/dconf, extensions, GDM | dconf locks | high |
| Cinnamon | 6.4 | X11 | GTK theme, LightDM/SDDM | limited | medium |
| LXQt / LXDE / MATE | 2.1.0 / 13 / 1.26.1 | X11 | basic | minimal | low |

Verified facts: Debian 13 (released 2025-08-09, supported ~5 years) ships these
versions; Debian's own live images are built with `live-build` and use the
**Calamares** installer (KDE/GNOME images need ≥ 4 GiB RAM).

## 4. Evaluation

### 4.1 Desktop target — **KDE Plasma wins**

Plasma has the **deepest branding hooks** of any Debian DE (one **global theme**
covers colours, widgets, splash, wallpaper, cursor, fonts; a themable **SDDM**
greeter; plymouth splash) which matches the Cybroid OS "brand once, apply everywhere"
goal. It is the only Debian DE with a **built-in Kiosk/lockdown framework**
(per-user/per-group restrictions) — the single most valuable feature for **shared
school computers**. Its default taskbar/application-menu layout resembles Windows,
easing migration. Plasma 6 is Wayland-first with an X11 fallback, is actively
maintained, and ships a mature remote-desktop story (see the mobile-control
research). GNOME is more polished "vanilla" but harder to brand and lock down;
Xfce/LXQt/Cinnamon lack the branding/lockdown depth or polish.

### 4.2 Server/pods target — **Xfce wins**

Pods run server-side and only need a **lightweight, reliable GUI reachable over
the network**; they do not need Plasma's branding depth or desktop polish. Xfce
4.20 is the lightest of the full-featured Debian desktops, extremely stable,
X11-first (predictable for headless/VM/RDP-style access), and trivially scriptable
into an image. It keeps the pods image small and the resource footprint low, which
matters when many pods share a host. (GNOME/Plasma are too heavy here; LXQt/LXDE
are lighter still but less complete.)

### 4.3 Installer — **Calamares**

Debian's official live images use **Calamares**, so aligning with it keeps us on
the supported upstream path (vs a custom debian-installer setup). It also gives a
graphical, brandable install flow suitable for students/customers.

## 5. Decision

1. **Desktop target:** default DE = **KDE Plasma 6.3** (Wayland default, X11
   fallback). Branding via a Plasma **global theme** + **SDDM** greeter theme +
   Plymouth splash; lockdown via **KDE Kiosk** profiles for school machines.
   Also publish an optional **"Cybroid OS Lite" ISO on Xfce 4.20** for low-spec lab
   hardware.
2. **Server/pods target:** ships **Xfce 4.20** as a lightweight, network-reachable
   desktop (with a display-manager greeter and remote-access path).
3. **Installer:** **Calamares** on the desktop ISO (matches Debian Live).
4. A **customized KDE/phone application** to control the desktop from a mobile
   phone is a new component; its design is scoped separately in
   `docs/research/desktop-mobile-control.md` and will get its own ADR.

## 6. Consequences

**Positive**
- One branding source re-skinned into Plasma (desktop) and Xfce (server/pods).
- School machines get real per-group lockdown via KDE Kiosk.
- Server/pods stay light and predictable with Xfce.
- Calamares keeps the desktop ISO on Debian's supported live-build path.

**Negative / risks**
- Two DEs means two theming paths (Plasma global theme vs GTK theme) to maintain
  in `common/branding/`.
- Plasma needs ~4 GB RAM for the live environment (the Xfce "Lite" ISO covers
  2 GB machines).
- Debian 13 stays on Plasma 6.3.x; newer Plasma features only arrive with a future
  Debian release or backports.
- Adding a DE to the server/pods image grows it — confirm any pods that must stay
  truly minimal.

**Out of scope:** the phone app's implementation (separate ADR), the Pi kiosk
runtime (ADR-0002), and the APT repo tool.

## 7. Open questions

| # | Question | Default until answered |
|---|---|---|
| 1 | Do **container/pod** images also get Xfce, or only server VM/ISO images? A DE inside a minimal container is unusual. | Server VM/ISO gets Xfce; containers stay light unless told otherwise |
| 2 | Exact KDE Kiosk rules for school machines (what may students change, which apps are allowed)? | Reasonable school lockdown, refined later |
| 3 | Is an arm64 desktop ISO needed, or x86_64 only? | x86_64 first |
| 4 | Does any lab software require X11, forcing the desktop to default to X11 over Wayland? | Wayland default, X11 session available |

## 8. Verification log

Versions checked against official Debian sources on 2026-10-11 (Debian 13
"trixie" release announcement and release notes: GNOME 48, KDE Plasma 6.3,
Xfce 4.20, LXQt 2.1.0; Qt 6.8.2, KDE Frameworks 6.13; Debian Live manual —
`live-build` + Calamares installer). Nothing here is asserted from memory alone.
