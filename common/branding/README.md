# CIT-OS branding

Single source of truth for CIT-OS branding. Branding is defined **once** here and
rendered per target by [`tools/render-brand.py`](../../tools/render-brand.py)
into a **filesystem overlay** (paths are final install paths). Every builder
consumes the overlay the same way, so the Pi image, desktop ISO, server/pod
image, containers and the `citos-base` package all show identical branding.

```
common/branding/
  brand.toml        identity + palette + asset roles      (what the brand is)
  targets.toml      per-target component lists            (what each image gets)
  logo/             source art (SVG)
  templates/        text templates (identity, kiosk, plymouth, wallpaper)
```

## Rendering

```bash
tools/render-brand.py --list                         # targets and their components
tools/render-brand.py --target rpi --out <overlay>   # render one target
tools/render-brand.py --target desktop --out <overlay> --only identity,wallpaper
```

`icons`, `plymouth` and `wallpaper` rasterise SVG with `rsvg-convert`
(`librsvg2-bin`; it is in the devcontainer). Set `RSVG_CONVERT` to override.

| Component | Installs |
|---|---|
| `identity` | `/usr/lib/os-release` (incl. `VARIANT`/`VARIANT_ID` per target), `/etc/motd`, `/etc/issue` |
| `assets` | `/usr/share/citos/branding/{logo,logo-animated,mark,mark-animated}.svg` |
| `icons` | `/usr/share/citos/branding/{logo,mark}-<n>.png`, hicolor `apps/citos` icons, `/usr/share/pixmaps/citos.png` |
| `plymouth` | `/usr/share/plymouth/themes/citos/` — mark fades in, then breathes |
| `kiosk` | `/usr/share/citos/kiosk/` — branded page with the animated mark (cage + Chromium) |
| `wallpaper` | `/usr/share/backgrounds/citos/citos.svg` + PNGs at 1080p / 1440p / 2160p |

| Target | Components | Consumer |
|---|---|---|
| `base` | identity, assets | `tools/build-package.sh` → `citos-base` .deb |
| `rpi` | identity, assets, icons, plymouth, kiosk, wallpaper | `targets/rpi/build.sh` → pi-gen `files/` |
| `desktop` | identity, assets, icons, plymouth, wallpaper | live-build `config/includes.chroot/` (Phase 6) |
| `server` | identity, assets, icons, plymouth, wallpaper | server/pod image overlay (Phase 5) |
| `container` | identity, assets | Dockerfile `COPY overlay/ /` (Phase 4) |

**Adding a target:** add a `[name]` table to `targets.toml`. **Adding a
component:** add a function to `COMPONENTS` in `render-brand.py` (and a template
under `templates/` if it emits text). **Rebranding:** change `brand.toml` and
`logo/` only; nothing else names files or colours.

## Logo assets

Installed files use **role names** (`logo.svg`, `mark.svg`, ...), so consumers
never depend on source file names.

| Role (`brand.toml [assets]`) | Source | Use |
|---|---|---|
| `logo` | `logo/cybroid-logo.svg` | App-icon tile (navy rounded square). Icons, pixmaps. |
| `logo_animated` | `logo/cybroid-logo-animated.svg` | Tile, CSS-animated: draws itself in, then pulses. Browsers only. |
| `mark` | `logo/cybroid-mark.svg` | Transparent mark, static. Plymouth, wallpaper, any raster. |
| `mark_animated` | `logo/cybroid-mark-animated-transparent.svg` | Transparent mark, CSS-animated. Kiosk page. |

`cybroid-mark.svg` is **derived**: it is `cybroid-logo.svg` with the background
`<rect class="cy-bg">` removed. Regenerate it if the logo changes:

```bash
grep -v '<rect class="cy-bg"' logo/cybroid-logo.svg > logo/cybroid-mark.svg
```

The animated SVGs start from an "undrawn" state, so rasterisers (rsvg, Inkscape)
render them blank or broken. Only use them where a browser renders the SVG.

`logo/legacy/` holds the earlier CIT assets imported from `novaoneltd/cit`
(`cit-logo.svg`, `cit-logo.png`, `cit-mark.png`, `cit-icon-64.png`,
`cit-favicon.png`). They are no longer used by any build.

Palette values in `brand.toml` are **derived** from the Cybroid logo
(band `#3a7cff` → `#2c9dff` → `#1ccbff`, circuit `#18d8ff`, tile `#16224a` → `#0d1530`).

## To confirm with the brand owner

- [ ] The logo SVGs are titled **"Cybroid Technologies"**, while `brand.toml`
      says the vendor is **"Cybroid Institute of Technology"**. Which name ships?
- [ ] Is the derived palette correct, and which colour is the true "primary"?
- [ ] Provide a **monochrome** logo variant and a **light/dark** pair if they exist.
- [ ] Approve the generated wallpaper, or provide final wallpaper art.
- [ ] Can `logo/legacy/` be deleted?
- [ ] Licence/ownership confirmation that these assets may be redistributed in
      CIT-OS images shipped to customers.
