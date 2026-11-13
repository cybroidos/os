# CybroidOS Desktop: what "production ready" needs (research, 2026-11-13)

The 0.1.0 live ISO failed on real hardware: a black screen, no Wi-Fi list,
a touchpad that didn't click, an installer that couldn't finish, and Debian's
name on About and in os-release. This note records what was researched and
what each finding changed in 0.1.1. The work is listed in "Decisions".

## Identity (a Debian derivative)

- os-release: a derivative sets its own `ID` with `ID_LIKE=debian`, keeps it in
  `/usr/lib/os-release`, and prefixes any new fields with its own name
  ([os-release(5)](https://www.freedesktop.org/software/systemd/man/253/os-release.html)).
  live-build wrote Debian's file over `/etc/os-release` in the image, so
  everything (System Settings' About, `hostnamectl`) said Debian.
- dpkg vendor: Debian's derivative guidelines say a derivative should set the
  dpkg vendor to its own name, and that rebuilt packages carry a
  distribution-specific version suffix
  ([Derivatives/Guidelines](https://wiki.debian.org/Derivatives/Guidelines)).
- KDE's About page reads `/etc/xdg/kcm-about-distrorc` (name, logo, website,
  variant). Its logo otherwise comes from os-release's `LOGO`, and the page
  shows `NAME`, not `PRETTY_NAME`
  ([KInfoCenter docs](https://develop.kde.org/docs/administration/kinfocenter/),
  [bug 481746](https://bugs.kde.org/show_bug.cgi?id=481746)).

## The live session

- Home folders (Documents, Downloads…) come from `xdg-user-dirs-update`, run
  by the session's autostart. Live images without the `xdg-user-dirs` package
  get only the folders other tools make, such as Desktop
  ([Fedora 2359532](https://bugzilla.redhat.com/show_bug.cgi?id=2359532),
  [Kali 6104](https://bugs.kali.org/view.php?id=6104)).
- live-config creates the live user through `user-setup`. The image was built
  with `--apt-recommends false`, which dropped it, so there was no user and
  SDDM's autologin failed. The same option also dropped `wpasupplicant`, so
  NetworkManager had no Wi-Fi.

## The installer (Calamares 3.3, Debian 13)

- Branding is `branding.desc`. `welcomeStyleCalamares: false` makes the
  welcome line read "Welcome to the CybroidOS installer". `sidebar` and
  `navigation` accept `qml`, and Calamares then loads
  `calamares-sidebar.qml` and `calamares-navigation.qml` from the branding
  folder; with these, our own design replaces the stock sidebar and "About
  Calamares" button. The QSS stylesheet styles the pages, but not the
  stock sidebar list, which is drawn in C++
  ([Calamares branding.desc](https://github.com/calamares/calamares/blob/calamares/src/branding/default/branding.desc),
  [NX OS on Calamares QML](https://nxos.org/news/updates-calamares-qml/)).
- Debian's `calamares-settings-debian` helper installs GRUB with `apt-get`,
  and a live ISO has no package source, so every install failed. Its
  packages step uses `remove`, which also stops at the first package name
  the image doesn't have. We use our own helper, and `try_remove`.
- Disks: Calamares can start on "Erase disk" (`initialPartitioningChoice`)
  with a swap file (`initialSwapChoice: file`).

## A light but complete desktop

- Power: Debian moved to power-profiles-daemon; TLP conflicts with it, and
  TLP's maintainers advise against running both
  ([TLP FAQ](https://linrunner.de/tlp/faq/ppd.html)). We keep PPD, which
  Plasma's battery applet drives.
- Out of memory: Fedora Workstation (since 34) and Ubuntu Desktop (since
  22.04) enable systemd-oomd by default, with zram
  ([Fedora change](https://fedoraproject.org/wiki/Changes/EnableSystemdOomd),
  [Ubuntu LP 2139289](https://lists.snapcraft.io/archives/foundations-bugs/2026-January/545239.html)).
  We do the same: `zram-tools` (half the RAM, zstd) and `systemd-oomd`, so a
  4 GB machine stays responsive instead of freezing.
- Brightness: Plasma's PowerDevil owns the backlight. `brightnessctl` works
  without root through the `brightness-udev` rules for the `video` group,
  but Plasma doesn't notice its changes
  ([bug 495381](https://bugs.kde.org/show_bug.cgi?id=495381)). So Control
  Centre uses PowerDevil's D-Bus API, falling back to brightnessctl only
  when PowerDevil has no backlight.
- Touchpads: libinput leaves tapping off; an X11 InputClass turns on tap to
  click, two-finger right click and natural scrolling.
- Security without effort: `unattended-upgrades` for Debian's security
  updates, and `ufw` with incoming connections closed except Remote Desktop,
  which is allowed on Tower only.

## Decisions (0.1.1)

| Area | Change |
|---|---|
| Name | CybroidOS everywhere; id `cybroid` (os-release `ID=cybroid`, `ID_LIKE=debian`, packages `cybroid-*`, paths, theme ids). Transitional `citos-*` packages move installed systems over. The package mirror host (citos.cybroid.com) and the storage bucket keep their names: they are addresses, not branding. |
| Live ISO | Live user `cybroid` / `cybroid`, home folders, no screen lock, `user-setup`, Wi-Fi stack, firmware for common Wi-Fi chips, CybroidOS boot menus (GRUB and syslinux) with no black box before the splash. |
| Installer | Our sidebar and navigation in QML, a full stylesheet, a slideshow of the system, Erase disk by default with a swap file, GRUB without apt, `try_remove`, Kampala and British English. |
| Desktop | Control Centre: Wi-Fi (join in place), Bluetooth (devices in place), Airplane mode, Night Light, Do Not Disturb, Appearance and Design, screenshot, display brightness, sound with the output, now playing, battery. AM/PM clocks, zsh with history suggestions, a Google start page, theme pages hidden. |
| Apps | Firefox, ONLYOFFICE, VLC, Okular, Gwenview, Kate, KWrite, Ark, KCalc, Spectacle, System Monitor, Discover with Flathub. No LibreOffice (heavy). |
| System | zram + systemd-oomd, fstrim weekly, unattended security updates, ufw, fwupd, cups. |
