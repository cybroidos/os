# Pi 4 hardware release checklist

QEMU results are not hardware validation. Complete this on real hardware for
every release candidate and attach the signed result to the release.

| # | Check | Pass |
|---|---|---|
| 1 | Flash the release `.img.xz` to a known-good SD card | [ ] |
| 2 | Pi 4 boots to the branded Plymouth splash with no console text | [ ] |
| 3 | Kiosk app launches fullscreen; no shell or desktop leaks | [ ] |
| 4 | `cat /etc/os-release` shows `NAME="Cybroid OS"`, `ID=cybroidos` | [ ] |
| 5 | `hostname` is `cybroid`; `/etc/motd` and `/etc/issue` are branded | [ ] |
| 6 | First boot regenerated `/etc/machine-id` and SSH host keys | [ ] |
| 7 | No default password works; first login forces a password change | [ ] |
| 8 | SSH is off unless a provisioning key was supplied | [ ] |
| 9 | With a provisioning key: pubkey SSH works, password SSH and root login fail | [ ] |
| 10 | Signed APT repo updates install and `InRelease` verifies | [ ] |
| 11 | Reboot three times; kiosk restarts cleanly each time | [ ] |
| 12 | Power-loss test: filesystem is not corrupted | [ ] |
| 13 | Network Deny-Incoming baseline confirmed (`ufw status`) | [ ] |
| 14 | Release manifest checksums match the downloaded image | [ ] |

Record: date, tester, hardware revision, SD card, image SHA-256, deviations.
