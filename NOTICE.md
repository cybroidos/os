# CIT-OS notices

This project is published as open source with deliberate, narrow restrictions
that protect the brand without locking down the code. See
[`docs/LICENSING.md`](docs/LICENSING.md) for the rationale.

## Licence map

| Material | Licence | File |
|---|---|---|
| Build system, scripts, Debian packaging, configuration | GNU GPL v3 or later | [`LICENSE`](LICENSE) |
| Brand assets (logos, icons, wallpapers, palette) | Creative Commons BY-NC 4.0 | [`LICENSE-ASSETS`](LICENSE-ASSETS) |
| Documentation and ADRs | GNU GPL v3 or later | [`LICENSE`](LICENSE) |
| Debian / Raspberry Pi OS upstream packages | Their own licences | Shipped package copyright files |
| Optional proprietary components | Vendor EULA, not in this repo | [`docs/PROPRIETARY-COMPONENTS.md`](docs/PROPRIETARY-COMPONENTS.md) |

## Trademark policy

CIT, CIT-OS, Cybroid, the CIT mark, and associated logos are trademarks of the
Cybroid Institute of Technology. You may use the build system under the GPL to
create your own images, but:

- you may not use the CIT/Cybroid names or logos to imply endorsement of your
  derivative;
- redistributing an unmodified branded image under the CIT name requires
  written permission;
- modified or derived images must be renamed and must not reuse the brand
  assets unless separately licensed.

The CC BY-NC licence on the artwork additionally prevents commercial reuse of
the logos themselves. This is the intentional "restrictive" part of the
release; the code remains fully free software.

## Third-party notices

CIT-OS is built on Debian 13 "Trixie" and, for the Pi target, Raspberry Pi OS.
Those projects and every packaged dependency retain their own copyright and
licence terms. "Raspberry Pi" is a trademark of Raspberry Pi Ltd and is used
only for compatibility attribution; no Raspberry Pi logo is redistributed by
this project without the required licence.

Generated release images must include a SBOM / package manifest produced by
[`tools/release-manifest.sh`](tools/release-manifest.sh).
