# Changelog

What changed in each CybroidOS version, newest first. The version is
`[identity] version` in `common/branding/brand.toml`; a release is tagged
`v<version>` (see docs/RELEASE-CHECKLIST.md). Every package carries the same
version.

## [Unreleased]

### Added
- **One ISO, editions chosen at first sign-in:** the welcome asks what the
  computer is for and installs the chosen editions (Developer, Security,
  Network, Engineering, Classroom) from deb.cybroid.com; Settings > About >
  Add an edition does the same later. The download is the same for
  everyone, and an edition adds nothing to it.
- **Industry-standard tools in the editions:** Docker Engine from Docker
  (Buildx and Compose included) for Developer and for Security's Kali
  container; Visual Studio Code from Microsoft's repository; Postman and
  DBeaver; PuTTY and WinBox; Arduino IDE 2; Scratch and the current
  GeoGebra.
- **Flathub in the App Centre:** apps that Debian doesn't carry (Ghidra,
  Android Studio and many more) install from the App Centre.
- **Editions, revised:** each package checked against Debian 13, one tool
  per job.
  - Developer: VS Code, Docker, Git with LFS and the GitHub CLI, GCC and
    Clang with CMake, Meson, Ninja, GDB, Valgrind; Python, Go, Rust,
    Node.js, Java (OpenJDK, Maven), PHP with Composer; PostgreSQL, MariaDB,
    Redis and SQLite clients; Postman, DBeaver; Vim, tmux, ripgrep, jq.
  - Security: Kali's tools in a container (Burp Suite, Metasploit), with
    web testing (Gobuster, ffuf, WhatWeb, sslscan, testssl.sh), Bettercap,
    Impacket, pwntools, Wi-Fi (hcxtools, Reaver), forensics (TestDisk,
    foremost, ExifTool), audits (Lynis, rkhunter), Tor, WireGuard, OpenVPN
    and KeePassXC.
  - Network: PuTTY, WinBox, Zenmap, bandwidth and Wi-Fi monitors, a TFTP
    server and dnsmasq for lab devices, FileZilla, Remmina, FRRouting and
    VPCS, and Ansible, Netmiko, Paramiko and Scapy.
  - Engineering: Arduino IDE 2, SimulIDE, Fritzing; Icarus Verilog, GHDL
    and GTKWave; PulseView; avrdude, esptool and OpenOCD; Octave's control
    and signal packages; SymPy and pandas; JupyterLab.
  - Classroom: Scratch, GeoGebra, Kiwix (Wikipedia offline), OpenBoard
    (whiteboard), Tux Paint, TuxMath, KTouch, Thonny, Avogadro, Stellarium,
    Parley, Audacity.
- Downloads from cybroid.com/cybroidos (download.cybroid.com): the ISO of
  the newest two releases, with its checksum and package manifest,
  stored in Cybroid's Appwrite storage (or Cloudflare R2) and served with
  their sizes, so browsers show progress and can resume; older releases on
  the Internet Archive, linked from their GitHub Releases.

## [0.1.16] - 2026-11-23

### Added
- **Account menu:** your picture at the top right, with your account, Lock,
  Sleep, Switch user, Sign out, Restart and Shut down; Lock, Restart and Shut
  down at the bottom right of Launchpad too.
- **Welcome:** at a new account's first sign-in, choose Horizon or Hex, add
  a picture, get online, and see where things are. Every step can be skipped.
- **Editions:** Security (with Kali's tools in a container), Developer,
  Network, Engineering and Classroom (Veyon, learning apps, lab accounts reset
  at each start), each its own ISO and installable on any CybroidOS.
- **Your own picture in Hex:** it goes behind Hex's frame, dial and leaders,
  toned to Hex's colours; Settings > Appearance > Desktop picture.
- **Office:** Word, Excel and PowerPoint files open in ONLYOFFICE, which now
  updates from deb.cybroid.com; Carlito and Caladea stand in for Calibri and
  Cambria.
- **Home network** switch in Settings > Wi-Fi: phones (KDE Connect) reach the
  computer there and over Tower, nowhere else.
- Every ISO gets a release manifest: checksums and every package with its
  version.

### Changed
- New accounts start in zsh again (Debian 13's installer had ignored the
  setting); accounts given bash by mistake move to zsh on upgrade.
- No box over the CybroidOS mark once a boot entry is chosen.
- Lighter at idle: Discover's notifier no longer runs, KDE Connect starts
  once a phone is paired, the on-screen keyboard only on touchscreens, and
  file search indexes names, not contents.
- Tower, Remote Desktop and SSH run only on computers that have joined Tower.
- Licensed for the public: GPL-3.0-or-later for code, CC BY-NC 4.0 for the
  brand artwork.

### Security
- KDE Connect's ports were open on every network; now Tower and networks
  marked home only.

## [0.1.15] - 2026-11-16
- Every app shows its CybroidOS name, also while it runs.

## [0.1.14]
- An on-screen keyboard on the sign-in screen and the desktop.

## [0.1.0 to 0.1.13]
- The first CybroidOS releases: the Horizon and Hex designs, our own
  Settings and Camera, signed updates from deb.cybroid.com, Tower, and the
  installer ISO. See the history for each change.

[Unreleased]: https://github.com/cybroidos/os/compare/v0.1.16...HEAD
[0.1.16]: https://github.com/cybroidos/os/releases/tag/v0.1.16
