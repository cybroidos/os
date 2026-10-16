#!/usr/bin/env python3
"""Render CIT-OS branding for one build target as a filesystem overlay.

Branding is defined once in common/branding/ (brand.toml + logo/ + templates/)
and every target picks the components it needs from common/branding/targets.toml.
The output directory mirrors the final install paths, so any builder consumes
it the same way: pi-gen files/, live-build includes.chroot/, a Dockerfile
`COPY overlay/ /`, or a .deb source tree.

  tools/render-brand.py --target rpi --out <dir>
  tools/render-brand.py --target base --out <dir> --only identity
  tools/render-brand.py --list
  tools/render-brand.py --emit-dart apps/kiosk/lib/src/brand.g.dart

Components:

  identity   usr/lib/os-release, etc/motd, etc/issue
  assets     usr/share/<id>/branding/{logo,logo-animated,mark,mark-animated}.svg
  icons      usr/share/<id>/branding/{logo,mark}-<n>.png
             usr/share/icons/hicolor/<n>x<n>/apps/<id>.png (+ scalable SVG)
             usr/share/pixmaps/<id>.png
  plymouth   usr/share/plymouth/themes/<id>/{<id>.plymouth,<id>.script,logo.png,anim-NNN.png}
             etc/plymouth/plymouthd.conf (makes <id> the default theme)
  kiosk      usr/share/<id>/kiosk/{index.html,mark.svg}
  wallpaper  usr/share/backgrounds/<id>/{<id>.svg,<id>-<w>x<h>.png}

icons, plymouth and wallpaper rasterise SVG with rsvg-convert (librsvg2-bin;
override with $RSVG_CONVERT). The CSS-animated SVGs are only used where a
browser renders them; rasters always come from the static logo/mark.
"""

import argparse
import base64
import os
import pathlib
import shutil
import string
import subprocess
import sys
import tomllib

import brand_anim

REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent
BRANDING = REPO_ROOT / "common" / "branding"

ICON_SIZES = (16, 22, 24, 32, 48, 64, 128, 256, 512)
BRANDING_PNG_SIZES = (64, 128, 256, 512)
PLYMOUTH_LOGO_SIZE = 256
PLYMOUTH_FPS = 25
WALLPAPER_SIZES = ((1920, 1080), (2560, 1440), (3840, 2160))


class Context:
    def __init__(self, brand_dir: pathlib.Path, target: str, release: str, out: pathlib.Path):
        self.brand_dir = brand_dir
        self.brand = tomllib.loads((brand_dir / "brand.toml").read_text())
        targets = tomllib.loads((brand_dir / "targets.toml").read_text())
        if target not in targets:
            sys.exit(f"render-brand: unknown target '{target}' (have: {', '.join(targets)})")
        self.target_name = target
        self.target = targets[target]
        self.release = release
        self.out = out
        self.ident = self.brand["identity"]
        self.colors = self.brand["colors"]
        self.id = self.ident["id"]

    def asset(self, role: str) -> pathlib.Path:
        return self.brand_dir / self.brand["assets"][role]

    def vars(self, **extra: str) -> dict:
        v = {k: str(val) for k, val in self.ident.items()}
        v.update({f"color_{k}": val for k, val in self.colors.items()})
        v["rgb_background"] = rgb_float(self.colors["background"])
        v["release"] = self.release
        v.update(extra)
        return v

    def template(self, rel: str, **extra: str) -> str:
        text = (self.brand_dir / "templates" / rel).read_text(encoding="utf-8")
        return string.Template(text).substitute(self.vars(**extra))

    def write(self, rel: str, content: str | bytes) -> pathlib.Path:
        path = self.out / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        if isinstance(content, bytes):
            path.write_bytes(content)
        else:
            path.write_text(content, encoding="utf-8")
        return path

    def copy(self, src: pathlib.Path, rel: str) -> None:
        dst = self.out / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(src, dst)


def rgb_float(value: str) -> str:
    value = value.lstrip("#")
    return ", ".join(f"{int(value[i:i + 2], 16) / 255:.4f}" for i in (0, 2, 4))


def rsvg() -> str:
    exe = os.environ.get("RSVG_CONVERT") or shutil.which("rsvg-convert")
    if not exe:
        sys.exit("render-brand: rsvg-convert not found (apt install librsvg2-bin, or set RSVG_CONVERT)")
    return exe


def rasterise(src: pathlib.Path, dst: pathlib.Path, width: int, height: int) -> None:
    dst.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        [rsvg(), "-w", str(width), "-h", str(height), "-o", str(dst), str(src)],
        check=True,
    )


# --- components --------------------------------------------------------------

def identity(ctx: Context) -> None:
    ident, t = ctx.ident, ctx.target
    lines = [
        f'PRETTY_NAME="{ident["pretty_name"]} {ident["version"]} ({ctx.release})"',
        f'NAME="{ident["name"]}"',
        f'VERSION_ID="{ident["version"]}"',
        f'VERSION="{ident["version"]} ({ctx.release})"',
        f"VERSION_CODENAME={ctx.release}",
        f"ID={ident['id']}",
        f"ID_LIKE=\"{t.get('id_like', 'debian')}\"",
    ]
    if "variant" in t:
        lines.append(f'VARIANT="{t["variant"]}"')
    if "variant_id" in t:
        lines.append(f"VARIANT_ID={t['variant_id']}")
    lines += [
        f'HOME_URL="{ident["home_url"]}"',
        f'SUPPORT_URL="{ident["support_url"]}"',
        f'BUG_REPORT_URL="{ident["bug_report_url"]}"',
        f'DOCUMENTATION_URL="{ident["documentation"]}"',
        f'VENDOR_NAME="{ident["vendor"]}"',
    ]
    if "icons" in t["components"]:
        lines.append(f"LOGO={ctx.id}")  # hicolor icon name
    lines.append("")
    ctx.write("usr/lib/os-release", "\n".join(lines))
    ctx.write("etc/motd", ctx.template("identity/motd"))
    ctx.write("etc/issue", ctx.template("identity/issue"))


def assets(ctx: Context) -> None:
    for role in ("logo", "logo_animated", "mark", "mark_animated"):
        ctx.copy(ctx.asset(role), f"usr/share/{ctx.id}/branding/{role.replace('_', '-')}.svg")


def icons(ctx: Context) -> None:
    base = ctx.out / f"usr/share/{ctx.id}/branding"
    for n in BRANDING_PNG_SIZES:
        rasterise(ctx.asset("logo"), base / f"logo-{n}.png", n, n)
        rasterise(ctx.asset("mark"), base / f"mark-{n}.png", n, n)
    hicolor = ctx.out / "usr/share/icons/hicolor"
    for n in ICON_SIZES:
        rasterise(ctx.asset("logo"), hicolor / f"{n}x{n}/apps/{ctx.id}.png", n, n)
    ctx.copy(ctx.asset("logo"), f"usr/share/icons/hicolor/scalable/apps/{ctx.id}.svg")
    rasterise(ctx.asset("logo"), ctx.out / f"usr/share/pixmaps/{ctx.id}.png", 128, 128)


def plymouth(ctx: Context) -> None:
    theme = f"usr/share/plymouth/themes/{ctx.id}"
    n = PLYMOUTH_LOGO_SIZE
    rasterise(ctx.asset("mark"), ctx.out / theme / "logo.png", n, n)

    # The logo's CSS draw-in, sampled to PNG frames the theme script plays.
    static = ctx.asset("mark").read_text(encoding="utf-8")
    animated = ctx.asset("mark_animated").read_text(encoding="utf-8")
    frames = round(brand_anim.duration(animated) * PLYMOUTH_FPS) + 1
    tmp = ctx.out / theme / "frame.svg"
    for i in range(frames):
        tmp.write_text(brand_anim.frame(static, animated, i / PLYMOUTH_FPS), encoding="utf-8")
        rasterise(tmp, ctx.out / theme / f"anim-{i:03d}.png", n, n)
    tmp.unlink()

    ctx.write(f"{theme}/{ctx.id}.plymouth", ctx.template("plymouth/theme.plymouth"))
    ctx.write(f"{theme}/{ctx.id}.script",
              ctx.template("plymouth/theme.script", frames=str(frames)))
    ctx.write("etc/plymouth/plymouthd.conf",
              f"# Generated from common/branding.\n[Daemon]\nTheme={ctx.id}\nShowDelay=0\n")


def kiosk(ctx: Context) -> None:
    ctx.write(f"usr/share/{ctx.id}/kiosk/index.html", ctx.template("kiosk/index.html"))
    ctx.copy(ctx.asset("mark_animated"), f"usr/share/{ctx.id}/kiosk/mark.svg")


def wallpaper(ctx: Context) -> None:
    mark = base64.b64encode(ctx.asset("mark").read_bytes()).decode()
    svg = ctx.template("wallpaper/wallpaper.svg", mark_data_uri=f"data:image/svg+xml;base64,{mark}")
    src = ctx.write(f"usr/share/backgrounds/{ctx.id}/{ctx.id}.svg", svg)
    for w, h in WALLPAPER_SIZES:
        rasterise(src, src.with_name(f"{ctx.id}-{w}x{h}.png"), w, h)


def dart_color(hex_value: str) -> str:
    return f"Color(0xFF{hex_value.lstrip('#').upper()})"


def to_camel(key: str) -> str:
    head, *rest = key.split("_")
    return head + "".join(w.capitalize() for w in rest)


def dart_str(value: str) -> str:
    escaped = str(value).replace("\\", "\\\\").replace("'", "\\'").replace("$", "\\$")
    return f"'{escaped}'"


def emit_dart(brand_dir: pathlib.Path, path: pathlib.Path) -> None:
    """Brand identity, palette and logo geometry as Dart, for the Flutter kiosk."""
    brand = tomllib.loads((brand_dir / "brand.toml").read_text())
    ident, colors, assets = brand["identity"], brand["colors"], brand["assets"]
    geo = brand_anim.geometry(
        (brand_dir / assets["mark"]).read_text(encoding="utf-8"),
        (brand_dir / assets["mark_animated"]).read_text(encoding="utf-8"),
    )

    def pt(xy):
        return f"Offset({xy[0]}, {xy[1]})"

    def ease(name):
        return "Cubic({}, {}, {}, {})".format(*geo["ease"][name])

    out = [
        "// GENERATED by tools/render-brand.py --emit-dart from common/branding.",
        "// Do not edit; change brand.toml or the logo SVGs and regenerate.",
        "",
        "import 'package:flutter/animation.dart';",
        "",
        "import 'mark_model.dart';",
        "",
        "abstract final class Brand {",
    ]
    for key in ("name", "id", "vendor", "vendor_short", "pretty_name", "version", "support_url"):
        out.append(f"  static const String {to_camel(key)} = {dart_str(ident[key])};")
    for key, value in colors.items():
        out.append(f"  static const Color {to_camel(key)} = {dart_color(value)};")
    out += ["}", "", "const markGeometry = MarkGeometry("]
    out.append(f"  size: {geo['size']},")
    out.append(f"  introSeconds: {geo['duration']},")
    out.append(f"  circuitColor: {dart_color(geo['circuit_color'])},")
    out.append(f"  drawEase: {ease('draw')},")
    out.append(f"  tipEase: {ease('tip')},")
    out.append(f"  popEase: {ease('pop')},")
    out.append("  gradients: {")
    for gid, g in geo["gradients"].items():
        stops = ", ".join(str(o) for o, _ in g["stops"])
        cols = ", ".join(dart_color(c) for _, c in g["stops"])
        out.append(f"    {dart_str(gid)}: MarkGradient(")
        out.append(f"      {pt(g['from'])},")
        out.append(f"      {pt(g['to'])},")
        out.append(f"      [{cols}],")
        out.append(f"      [{stops}],")
        out.append("    ),")
    out.append("  },")
    out.append("  elements: [")
    for e in geo["elements"]:
        k = e["kind"]
        if k in ("band", "trace"):
            grad = dart_str(e["gradient"]) if e["gradient"] else "null"
            out += ["    MarkStroke(",
                    f"      d: {dart_str(e['d'])},",
                    f"      width: {e['width']},",
                    f"      round: {str(e['round']).lower()},",
                    f"      gradient: {grad},",
                    f"      glow: {str(e['glow']).lower()},",
                    f"      delay: {e['delay']},",
                    f"      duration: {e['duration']},",
                    "    ),"]
        elif k == "tip":
            out += ["    MarkTip(",
                    f"      d: {dart_str(e['d'])},",
                    f"      width: {e['width']},",
                    f"      gradient: {dart_str(e['gradient'])},",
                    f"      delay: {e['delay']},",
                    f"      duration: {e['duration']},",
                    f"      origin: {pt(e['origin'])},",
                    f"      angle: {e['angle']},",
                    "    ),"]
        elif k == "node":
            out += ["    MarkNode(",
                    f"      center: {pt(e['center'])},",
                    f"      r: {e['r']},",
                    f"      delay: {e['delay']},",
                    f"      duration: {e['duration']},",
                    "    ),"]
        elif k == "star":
            out += ["    MarkStar(",
                    f"      d: {dart_str(e['d'])},",
                    f"      center: {pt(e['center'])},",
                    f"      fill: {dart_color(e['fill'])},",
                    f"      delay: {e['delay']},",
                    f"      duration: {e['duration']},",
                    "    ),"]
    out += ["  ],", ");", ""]
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(out), encoding="utf-8")
    print(f"wrote {path}")


COMPONENTS = {
    "identity": identity,
    "assets": assets,
    "icons": icons,
    "plymouth": plymouth,
    "kiosk": kiosk,
    "wallpaper": wallpaper,
}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--target", help="profile from targets.toml (rpi, desktop, server, container, base)")
    parser.add_argument("--out", help="overlay output directory")
    parser.add_argument("--release", default="trixie")
    parser.add_argument("--brand-dir", default=str(BRANDING), help="branding directory (default: common/branding)")
    parser.add_argument("--only", help="comma-separated subset of the target's components")
    parser.add_argument("--list", action="store_true", help="list targets and their components")
    parser.add_argument("--emit-dart", metavar="PATH", help="write brand + logo geometry as Dart (Flutter kiosk)")
    args = parser.parse_args()

    brand_dir = pathlib.Path(args.brand_dir)
    if args.emit_dart:
        emit_dart(brand_dir, pathlib.Path(args.emit_dart))
        return
    if args.list:
        for name, t in tomllib.loads((brand_dir / "targets.toml").read_text()).items():
            print(f"{name:10} {' '.join(t['components'])}")
        return
    if not args.target or not args.out:
        parser.error("--target and --out are required")

    ctx = Context(brand_dir, args.target, args.release, pathlib.Path(args.out))
    components = list(ctx.target["components"])
    if args.only:
        wanted = args.only.split(",")
        unknown = [c for c in wanted if c not in components]
        if unknown:
            sys.exit(f"render-brand: {', '.join(unknown)} not in target '{args.target}'")
        components = [c for c in components if c in wanted]

    for name in components:
        COMPONENTS[name](ctx)
        print(f"  {name}")
    print(f"rendered {args.target} branding into {ctx.out}")


if __name__ == "__main__":
    main()
