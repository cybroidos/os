# Security policy

Cybroid Technologies (U) Ltd maintains CybroidOS and fixes security problems
in it.

## Supported versions

Fixes go to the latest CybroidOS release and reach installed computers through
the signed update channel (`deb.cybroid.com`, installed by `cybroid-sources`):
Debian's security updates and CybroidOS's own packages install by themselves.
Older ISOs are not rebuilt; install from the latest one, or let updates bring
an existing installation up to date.

## Reporting a vulnerability

**Please do not open a public issue for a security problem.** Report it
privately through GitHub ("Report a vulnerability" under this repository's
Security tab) or by email to **security@cybroid.com**, with:

- what the problem is and what an attacker could do with it;
- the CybroidOS version (`cat /etc/os-release`) and the hardware;
- steps to reproduce it, and a proof of concept if you have one.

We acknowledge reports within **3 working days**, confirm severity within
**10 working days**, and aim to ship a fix or mitigation within **30 days**
for critical and high issues and **90 days** for the rest. We credit reporters
who wish to be named.

## Scope

- This repository: packages, build scripts and image definitions.
- CybroidOS images and the update channel at `deb.cybroid.com`.

Problems in packages CybroidOS takes unchanged from Debian belong with
[Debian's security team](https://www.debian.org/security/); tell us too if
they affect CybroidOS in a particular way.

## What every release keeps to

- No default password on an installed system: the installer asks for one.
  The live system's own account (`cybroid`/`cybroid`) exists only in memory,
  with the firewall on and remote desktop off.
- A firewall that refuses incoming connections, AppArmor, and kernel
  hardening settings, on from the first boot. SSH and remote desktop run
  only on a computer that has joined Tower (the organisation's private
  network) and answer only over it; SSH never accepts a password from any
  other network, and never root. Phones (KDE Connect) reach the computer
  over Tower or on a network its owner marks as home.
- Every CybroidOS package is signed with the CybroidOS archive key; Debian's
  are checked against Debian's keys.
- Each release publishes SHA-256 checksums and a package manifest
  (`tools/release-manifest.sh`).
