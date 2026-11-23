# CybroidOS packages

Everything reusable in CybroidOS ships as Debian packages, so a desktop ISO,
a server image, a container or any Debian 13 machine gets it the same way:
`apt install` from the CybroidOS APT repository ([ADR-0007](../../docs/adr/ADR-0007-shared-packages-and-apt-repo.md)).
Images only add what is specific to one image (users, autologin, the kernel
command line).

| Package | Arch | Contents | Used by |
|---|---|---|---|
| `cybroid-base` | all | `/etc/os-release` identity, login banners, logo SVGs | every target |
| `cybroid-sources` | all | apt sources at `deb.cybroid.com` (Debian 13's archive and security updates under the CybroidOS name; Debian's own entries set aside, restored on removal) | server, desktop, container images; the desktop ISO |
| `cybroid-plasma` | all | CybroidOS Desktop: KDE Plasma 6 in the CybroidOS Horizon look (colour scheme, top bar and floating dock, SDDM sign-in, splash), Plymouth, Firefox policy, xrdp | desktop VM image; the desktop ISO |
| `cybroid-artwork` | all | hicolor icons, wallpapers (1080p–2160p), Hex's drawings for every screen shape | desktop, server |
| `cybroid-plymouth-theme` | all | animated boot splash; sets itself as the theme | desktop, server |
| `cybroid-ui`, `cybroid-settings`, `cybroid-camera` | amd64, arm64 | our own apps (`apps/desktop`, built by `tools/build-native.sh`) | the desktop |
| `cybroid-edition-*` | all | the editions: one profession's tools on top of the desktop (Security, Developer, Network, Engineering, Classroom) | edition ISOs; any desktop |

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
tools/build-package.sh cybroid-plasma          # one package
```

The builder uses plain `dpkg-deb`. Our native apps are built first by
`tools/build-native.sh` (`NATIVE_ROOT`); `cybroid-artwork` and
`cybroid-plymouth-theme` need `rsvg-convert`.

## Publishing and installing

`tools/publish-apt-repo.sh dist/*.deb` adds packages to the signed reprepro
repository in `apt-repo/published/` (needs the CybroidOS signing key in GnuPG).
On a machine:

```bash
sudo curl -fsSLo /tmp/cybroid-sources.deb https://deb.cybroid.com/cybroid-sources.deb
sudo apt install /tmp/cybroid-sources.deb     # the CybroidOS sources and signing key
sudo apt update
sudo apt install cybroid-plasma               # the desktop; or cybroid-base, an edition, ...
```
