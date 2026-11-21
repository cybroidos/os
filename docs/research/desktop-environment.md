# Research: Desktop environment for the Cybroid OS desktop target

- **Status:** **decided — see [ADR-0003](../adr/ADR-0003-desktop-environment.md)**
  (KDE Plasma default desktop; Xfce for the server/pods target; Calamares).
- **Date:** 2026-10-11
- **Related:** [PLAN §6 Phase 6](../PLAN.md), ADR-0001 (Debian 13 Trixie),
  ADR-0003 (desktop environment), `desktop-mobile-control.md`
- **Question:** which desktop environment should the Cybroid OS **desktop** target
  ship? The owner asked to evaluate **KDE Plasma** specifically, "or anything
  better than it". The server/pods target also needs a DE → **Xfce**.

## TL;DR recommendation

- **Default desktop: KDE Plasma 6.3** (what Debian 13 ships). It is the best fit
  for Cybroid OS because it has, by a wide margin, the **deepest branding hooks**
  (global theme, SDDM greeter theme, splash, wallpaper, colour schemes) **and a
  built-in Kiosk/lockdown framework** for managing shared school machines.
- **Also offer a "Lite" variant on Xfce 4.20** for older lab hardware (2 GB RAM),
  and keep **Cinnamon 6.4** as the "familiar/Windows-like" alternative if Cybroid
  prefers it.
- **Not recommended for the general desktop:** GNOME 48 (harder to brand and
  lock down without extensions) and the very light LXQt/LXDE (less polished).
- **"Anything better than Plasma?"** — for *combined branding + manageability +
  polish* on Debian 13, no. Plasma is the strongest choice.

## What Debian 13 "Trixie" actually ships (verified 2026-10-11)

| DE | Version in Trixie | Session | Branding hooks | Lockdown | Footprint |
|---|---|---|---|---|---|
| **KDE Plasma** | **6.3.x** (Qt 6.8.2, KF 6.13) | Wayland (default) + X11 | global theme, **SDDM** theme, splash, wallpaper | **KDE Kiosk** (per user/group) | high (4 GB+ RAM recommended) |
| GNOME | 48 | Wayland (default) | gsettings/dconf, extensions, GDM theme | dconf locks (limited) | high (4 GB+) |
| **Xfce** | **4.20** | X11 (Wayland experimental) | GTK theme, **LightDM**/SDDM | limited (config locks) | low (runs on 2 GB) |
| Cinnamon | 6.4 | X11 | GTK theme, LightDM/SDDM | limited | medium |
| LXQt | 2.1.0 | X11/Wayland | basic Qt theme | minimal | low |
| MATE / LXDE | 1.26.1 / 13 | X11 | basic | minimal | low |

Debian 13 released 2025-08-09, supported ~5 years (to 2030). Plasma 6 is the
first Plasma-6 release in Debian (up from 5.27), on a new Qt 6 / KDE
Frameworks 6 stack. Upstream Plasma 6.6 is the current **LTS** branch (KDE
support to 2029), but Debian freezes the version in the release and ships only
security/point fixes — this is the normal, expected "stable distro" trade-off.

## Why Plasma for the Cybroid OS desktop

1. **Branding depth.** Plasma is built to be re-skinned: a single **global
   theme** (colours, widgets, splash, wallpaper, cursor, fonts), a themable
   **SDDM** login greeter, and a themable boot splash. This matches the Cybroid OS
   goal "every visible surface is branded … defined once, shared across targets"
   better than any other Debian DE.
2. **Built-in Kiosk / lockdown.** The **KDE Kiosk framework** lets us restrict
   capabilities **per user and per group** (lock down System Settings pages,
   hide/replace menus, restrict actions). For *shared school computers* this is
   the single most valuable feature and it is unique among the Debian DEs.
3. **Familiar layout.** Plasma's default (taskbar + application menu) resembles
   Windows, reducing retraining for students/staff coming from Windows — relevant
   since a few customers also choose Cybroid OS over Windows.
4. **Wayland-ready and actively maintained** in Debian's supported stack for the
   whole trixie lifetime.
5. **Ships with the tooling our plan already assumes.** `live-build` has a KDE
   task and Debian's own KDE live image uses **Calamares** — the installer our
   Phase 6 plan already leans toward.

## Alternatives and when to pick them

- **Xfce 4.20 — "Cybroid OS Lite" for old hardware.** Low footprint, very stable,
  easy to brand via GTK theme + LightDM. X11-first (Wayland session is
  experimental). Pick this for lab machines with ≤ 2 GB RAM.
- **Cinnamon 6.4 — the "Windows-like" option.** Familiar, themable, good for
  non-technical users. Less configurable and no Kiosk framework, but a solid
  middle ground if Cybroid's staff prefer its feel over Plasma.
- **GNOME 48 — not recommended here.** Most polished "vanilla" experience, but
  branding needs extensions/dconf, the lockdown story is weaker, and it is the
  heaviest. Good general desktop, poor fit for *this* branding/management goal.
- **LXQt 2.1 / LXDE 13 / MATE — niche.** Lightest options; choose only if
  hardware is very constrained and polish/lockdown do not matter.
- **A locked-down "lab/kiosk" session instead of a full DE.** For exam/lab
  stations where only a browser or one app should be reachable, the Pi-style
  `cage`+Chromium (or Flutter) kiosk session is lighter and more locked-down than
  any full DE. Could be offered as an optional desktop **"lab mode"** later.

## Recommendation in context

- **Ship KDE Plasma 6.3 as the Cybroid OS desktop default.** Wire branding through a
  Plasma **global theme** + **SDDM** theme + Plymouth splash (all from
  `common/branding/`), and apply **KDE Kiosk** profiles per group for school
  machines.
- **Also publish a "Cybroid OS Lite" (Xfce 4.20) ISO** for low-spec lab PCs; keep
  Cinnamon as a documented alternative if requested.
- **Installer:** Debian's live images use **Calamares**; default Phase 6 to
  Calamares + live-build (matches upstream Debian Live).

## Open risks / to confirm

1. **RAM/disk budget** — Plasma needs ~4 GB RAM for the live environment; the
   "Lite" Xfce variant covers 2 GB machines. Confirm the actual Cybroid lab hardware
   specs.
2. **Lockdown requirements** — get the concrete rules (what students may change,
   which apps are allowed) before building the Kiosk profiles.
3. **Upstream-vs-Debian version gap** — trixie stays on Plasma 6.3.x; new Plasma
   features land only in a future Debian release (or backports). Acceptable, but
   worth stating.
4. **Wayland vs X11 defaults** — confirm any legacy/lab software (screen-sharing,
   lab tools) works on Wayland; keep an X11 session fallback.

## Sources

- Debian 13 "trixie" release announcement and release notes (§ "What's new":
  GNOME 48, KDE Plasma 6.3, Xfce 4.20, LXQt 2.1.0; "Plasma 6" section: Qt 6.8.2,
  KF 6.13, Plasma 6.3.x).
- Debian Live project + Live Manual (live-build, Calamares installer, desktop
  tasks; Debian's KDE live image needs ≥ 4 GiB RAM).
- KDE Developer docs — "Kiosk: Simple configuration management for large
  deployment".
- endoflife.date / eosl.date — KDE Plasma release cadence (6.6 = LTS, supported
  to 2029).
