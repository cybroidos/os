# CIT-OS branding assets

Single source of truth for CIT-OS branding. Builders and `<brand>-base` pull
from here, so branding is defined **once** and flows to all four targets.

## Contents

| File | Use |
|---|---|
| `brand.toml` | Identity + palette + asset paths. Read by build tooling. |
| `logo/cit-logo.svg` | Primary **vector** logo (preferred everywhere). |
| `logo/cit-logo.png` | 1254×1254 transparent PNG (raster fallback / large use). |
| `logo/cit-mark.png` | 256×256 square mark/icon (favicons, app icon, Plymouth). |
| `logo/cit-icon-64.png` | 64×64 icon. |
| `logo/cit-favicon.png` | 225×225 favicon. |
| `wallpaper/` | Desktop/kiosk wallpapers (pending final art). |

## Provenance

Assets were taken from the existing CIT web repo **`novaoneltd/cit`**:

- `extension/media/cit-logo.svg` → `logo/cit-logo.svg`
- `public/logo_transparent.png` → `logo/cit-logo.png`
- `extension/media/cit-icon.png` (Git LFS object) → `logo/cit-mark.png`
- `src/app/icon.png` → `logo/cit-icon-64.png`
- `public/favicon.png` → `logo/cit-favicon.png`

Palette values in `brand.toml` are **derived** from the logo SVG gradients
(`#557fc0` → `#69cce1` over navy `#112649` / `#0e2044`).

## To confirm with the brand owner

- [ ] Is the derived palette correct, and which colour is the true "primary"?
- [ ] Is `cit-logo.svg` the current, official lockup (not an older export)?
- [ ] Provide a **monochrome** logo variant and a **light/dark** pair if they exist.
- [ ] Provide wallpaper / boot-splash art (or approve a generated CIT-themed one).
- [ ] Licence/ownership confirmation that these assets may be redistributed in
      CIT-OS images shipped to customers.
