# CybroidOS packages

Everything reusable in CybroidOS ships as Debian packages, so a Pi image, a
desktop ISO, a server image or any Debian 13 machine gets it the same way:
`apt install` from the CybroidOS APT repository ([ADR-0007](../../docs/adr/ADR-0007-shared-packages-and-apt-repo.md)).
Images only add what is specific to one image (users, autologin, the kernel
command line).

| Package | Arch | Contents | Used by |
|---|---|---|---|
| `cybroid-base` | all | `/etc/os-release` identity, login banners, logo SVGs | every target |
| `cybroid-sources` | all | apt sources at `deb.cybroid.com` (Debian 13's archive and security updates under the CybroidOS name; Debian's own entries set aside, restored on removal) | server, desktop, container images; the desktop ISO |
| `cybroid-plasma` | all | CybroidOS Desktop: KDE Plasma 6 in the CybroidOS Horizon look (colour scheme, top bar and floating dock, SDDM sign-in, splash), Plymouth, Firefox policy, xrdp | desktop VM image; the desktop ISO |
| `cybroid-desktop` | all | CybroidOS Lite: Xfce in the CybroidOS colours, Firefox ESR, slick-greeter, xrdp | lite VM image |
| `cybroid-artwork` | all | hicolor icons, wallpapers (1080p–2160p) | desktop, server, Pi |
| `cybroid-plymouth-theme` | all | animated boot splash; sets itself as the theme | desktop, server, Pi |
| `python3-cybroid-robot` | all | `cybroid_robot` library: bus, config, supervisor, system service | robot services |
| `cybroid-system` | all | robot health + power service, MQTT broker config (localhost) | robots, kiosks |
| `cybroid-kiosk` | all | kiosk supervisor (`cybroid-kiosk`), `/etc/cybroid/kiosk.conf`, fallback page | any kiosk |
| `cybroid-kiosk-app` | arm64 | Flora, the Flutter kiosk app (`apps/kiosk`), with its engine and flutter-pi runtime | Pi kiosks |
| `cybroid-robot-hw` | all | robot firmware settings (SPI, I2S amp, power button) | the robot |
| `cybroid-robot` | all | metapackage: all of the above for the CIT service robot | robot image |

All packages share the CybroidOS version from `common/branding/brand.toml`.

## Layout of a package

```
common/packages/<name>/
  control      DEBIAN/control; @VERSION@ is filled in
  files/       static files at their install paths
  prepare      script that generates files: prepare <package-root> <repo-root>
  preinst postinst prerm postrm    maintainer scripts
```

Files under `etc/` become conffiles automatically. `copyright` here is shared
by every package.

## Building

```bash
tools/build-package.sh --all                 # every package whose inputs exist -> dist/
tools/build-package.sh cybroid-kiosk           # one package
KIOSK_BUNDLE=apps/kiosk/build/flutter-pi/aarch64-generic tools/build-package.sh cybroid-kiosk-app
```

The builder uses plain `dpkg-deb`, so the arm64 app package builds on any
machine without a cross-compiler. Its bundle comes from `flutterpi_tool build
--arch=arm64 --cpu=generic --release` and already contains the Flutter engine
and the matching prebuilt flutter-pi runtime; the generic engine runs on
Pi 4 (the robot and the dev board) as well as Pi 3 and 5.
`cybroid-artwork` and `cybroid-plymouth-theme` need `rsvg-convert`.

## Publishing and installing

`tools/publish-apt-repo.sh dist/*.deb` adds packages to the signed reprepro
repository in `apt-repo/published/` (needs the CybroidOS signing key in GnuPG).
On a machine:

```bash
sudo curl -fsSLo /usr/share/keyrings/cybroid-archive-keyring.gpg https://<repo-host>/cybroid-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/cybroid-archive-keyring.gpg] https://<repo-host> trixie main" \
  | sudo tee /etc/apt/sources.list.d/cybroid.list
sudo apt update
sudo apt install cybroid-robot        # or just cybroid-base, cybroid-plymouth-theme, ...
```
