# Adding a package to Cybroid OS

All packages live under `common/packages/<name>/` and are built by
`tools/build-package.sh <name>`. Branding is rendered from
`common/branding/brand.toml` into the source tree before `dpkg-buildpackage`.

## A normal package (with branding)

1. Create `common/packages/<name>/debian/` with `control`, `rules`, `changelog`,
   `copyright` and `install`.
2. `debian/install` must list every file produced by `tools/render-brand.py`
   that the package ships, otherwise debhelper compat 13's `dh_missing` will
   fail. See `common/packages/cybroidos-base/debian/install` for the canonical
   list.
3. Build and inspect:

   ```sh
   tools/build-package.sh <name>
   dpkg-deb -I dist/<name>_*.deb
   dpkg-deb -c dist/<name>_*.deb
   ```

4. Add the package to the CI required-file list (`.github/workflows/ci.yml`)
   and to any target that needs it (as a dependency of the relevant
   `cybroidos-*` metapackage, or directly in a builder).

## A metapackage (dependencies only)

Create `debian/no-branding` in the package directory. The build tool then skips
branding rendering. `debian/install` should still list the licence texts that
the tool copies into `usr/share/doc/<name>/`.

## A package with its own payload

`tools/build-package.sh` stages only `debian/` into its temporary source tree.
If your package ships files outside `debian/` (for example a D-Bus service),
keep a mirror under `debian/payload/` and have `debian/rules` copy it into
`debian/tmp` before `dh_install`. See `common/packages/cybroidos-control/` for
the pattern. Add the licence texts to `debian/install` as well.

Existing metapackages: `cybroidos-kiosk`, `cybroidos-rpi`,
`cybroidos-desktop`, `cybroidos-desktop-lite`, `cybroidos-server`.

## Rules

- Version comes from `brand.toml`; the build tool rewrites `debian/changelog`.
- Never commit secrets, signing keys or generated `.deb` files (`dist/` is
  ignored).
- Code is GPL-3.0-or-later; artwork is CC BY-NC 4.0 (`LICENSE-ASSETS`);
  record any non-free component in `docs/PROPRIETARY-COMPONENTS.md` and guard it
  with `tools/check-proprietary.sh`.
- Keep dependencies Debian Trixie-native; avoid third-party stores and snaps.
