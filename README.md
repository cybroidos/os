# CybroidOS

An operating system for engineers, analysts, security teams, schools and
offices, made by [Cybroid](https://cybroid.com/cybroidos). Secure from the
first boot, kept up to date on its own, and fast on the computers you already
have.

- **Two interfaces:** Horizon, a calm desktop anyone learns in minutes, and
  Hex, which keeps system and network status in view for operators. Each in
  light and dark, switchable at any time.
- **Updates by themselves:** security fixes and CybroidOS's own packages,
  signed, from `deb.cybroid.com`.
- **Private by default:** a firewall on from the first boot, AppArmor, no
  advertising and no tracking.
- **Built for organisations:** a private network (Tower) in Settings, and
  enrolment into [Hangar](https://cybroid.com/hangar) to manage every machine.

Requirements: a 64-bit Intel or AMD computer with 2 GB of memory (4 GB
recommended). Installing: [docs/user/INSTALL.md](docs/user/INSTALL.md).

## Editions

The same CybroidOS with one package of a profession's tools added; an
installed CybroidOS can become any of them, or several, by installing the
package.

| Edition | For | Package |
|---|---|---|
| Security | analysts and security teams; Kali's tools in a container | `cybroid-edition-security` |
| Developer | engineers who build software | `cybroid-edition-developer` |
| Network | network engineers and students | `cybroid-edition-network` |
| Engineering | electronics, CAD and science | `cybroid-edition-engineering` |
| Classroom | school computer rooms: Veyon, learning apps, lab accounts reset at each start | `cybroid-edition-classroom` |

CybroidOS is built on Debian 13 and KDE's Frameworks and Plasma.

## What's here

```
common/branding/   the brand: name, palette, mark, wallpapers (brand.toml)
common/packages/   the cybroid-* packages (ADR-0007)
apps/desktop/      our own apps: Settings, Camera, and the shared Cybroid.Ui module
targets/desktop/   the installer ISO (live-build and Calamares)
targets/server/    server and desktop VM images
targets/container/ a container image (Proxmox LXC, Docker, Podman)
tools/             build, branding and publishing scripts
docs/              user guides, ADRs and plans
```

## Building

On Debian 13 (or the devcontainer), with Docker for the ISO:

```sh
tools/build-package.sh --all              # the cybroid-* packages into dist/
tools/build-extras.sh iso                 # native apps and third-party pieces into dist/extra
sudo EXTRA_DEBS="$PWD/dist/extra" OUT="$PWD/out" targets/desktop/build-iso.sh
# an edition's ISO: EDITION=security (or developer, network, engineering, classroom)
```

The ISO lands in `out/`. CI builds it on every version bump
(`.forgejo/workflows/images.yml`).

## Contributing

Issues and pull requests are welcome. Keep changes small and say how you
tested them. Security problems: please follow [docs/SECURITY.md](docs/SECURITY.md)
instead of opening an issue.

## Licence

The code, packaging and configuration are free software under the
[GNU GPL v3 or later](LICENSE). The CybroidOS name, mark and artwork are under
[CC BY-NC 4.0](LICENSE-ASSETS) and are trademarks of Cybroid Technologies
(U) Ltd: a system you build from this source under another name must not use
them. Details in [NOTICE.md](NOTICE.md) and [docs/LICENSING.md](docs/LICENSING.md);
the few non-free pieces an image contains (device firmware) are listed in
[docs/PROPRIETARY-COMPONENTS.md](docs/PROPRIETARY-COMPONENTS.md).
