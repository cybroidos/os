# Release checklist

Before a CybroidOS release is announced. A release is a version bump in
`common/branding/brand.toml`: the ISO job (`.forgejo/workflows/images.yml`)
builds the ISO, its manifest and checksum, and publishes the packages to
`deb.cybroid.com`.

## Build

- [ ] CI is green (`ci.yml`: brand, shell, package checks).
- [ ] The ISO built from the tagged commit; its `.manifest.md` names that commit.
- [ ] The packages for this version are on `deb.cybroid.com` and `apt update`
      on an installed machine verifies the signature.

## Test (a real laptop and the test VM)

- [ ] The ISO starts on UEFI and on BIOS; the boot menu shows, and choosing an
      entry leaves the mark in place (no box).
- [ ] Live session: Wi-Fi, sound, displays, both looks (Horizon, Hex), light and dark.
- [ ] Install (whole disk, and alongside Windows); the new account's shell is
      zsh (`getent passwd <name>` ends in `/usr/bin/zsh`).
- [ ] Installed: silent boot, sign-in, updates (**Settings → Updates**),
      firewall on (`sudo nft list ruleset`), SSH and remote desktop off.
- [ ] An earlier install upgrades through `cybroid-update` without errors;
      the account menu appears in its top bar, and its shell is zsh.
- [ ] Account menu: Lock, Sleep, Sign out, Restart and Shut down each work
      (Restart and Shut down ask first); Launchpad's power row too.
- [ ] Office: a .docx, .xlsx and .pptx open in ONLYOFFICE; ONLYOFFICE
      updates from deb.cybroid.com.
- [ ] Tower: on a computer not on Tower, `systemctl is-active tailscaled xrdp ssh`
      are inactive; joining Tower starts them; KDE Connect reaches the computer
      over Tower and on a network marked home, not on others.
- [ ] Idle memory, signed in and idle five minutes on the test VM
      (`smem -tk` or `free -m`): record it here, and compare with the last release.

## Editions

- [ ] Each edition's ISO builds (`EDITION=<id>`), boots, and its tools start.
- [ ] Security: "Kali tools" creates the container and opens a shell.
- [ ] Classroom: a lab account's files are gone after a restart; a teacher's
      are not; Veyon Master sees a student computer.

## Legal and documents

- [ ] `LICENSE`, `LICENSE-ASSETS`, `NOTICE.md` and
      `docs/PROPRIETARY-COMPONENTS.md` are current.
- [ ] `common/packages/copyright` matches the licence map in `NOTICE.md`.
- [ ] `docs/user/` matches what ships; `README.md` names the version.
- [ ] Release notes: what changed, the checksum, the manifest, and a link to
      `docs/PROPRIETARY-COMPONENTS.md`.
