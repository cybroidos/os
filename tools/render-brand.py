#!/usr/bin/env python3
"""Render CybroidOS branding for one build target as a filesystem overlay.

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
import re
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
    # The hicolor icon name (cybroid-artwork ships it). Every target writes it:
    # cybroid-base's os-release replaces the image's on upgrade, and System
    # Info showed a placeholder when it lacked LOGO.
    lines.append(f"LOGO={ctx.id}")
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
    # A plain variant without the logo and wordmark, for the desktop and the
    # sign-in screen, where windows and the form sit in the middle.
    plain = re.sub(r"<image\b[^>]*/>|<text\b.*?</text>|<rect x=[^>]*/>", "", svg, flags=re.S)
    psrc = ctx.write(f"usr/share/backgrounds/{ctx.id}/{ctx.id}-plain.svg", plain)
    for w, h in WALLPAPER_SIZES:
        rasterise(psrc, psrc.with_name(f"{ctx.id}-plain-{w}x{h}.png"), w, h)
    # The light version (CybroidOS Horizon Light): the same picture on a bright
    # blue ground, as macOS pairs a light and a dark wallpaper (light, still
    # coloured: a near-white one washed the desktop out).
    light = re.sub(
        r'(<radialGradient id="bg".*?</radialGradient>)',
        '<radialGradient id="bg" cx=".5" cy=".42" r=".75">'
        '<stop offset="0" stop-color="#eef4ff"/><stop offset=".5" stop-color="#bcd2fa"/>'
        '<stop offset="1" stop-color="#7fa6ec"/></radialGradient>',
        svg,
        flags=re.S,
    )
    light = re.sub(r'(<g fill="none" stroke=")[^"]*(" stroke-opacity=")[^"]*', r"\g<1>#ffffff\g<2>.35", light)
    lsrc = ctx.write(f"usr/share/backgrounds/{ctx.id}/{ctx.id}-light.svg", light)
    for w, h in WALLPAPER_SIZES:
        rasterise(lsrc, lsrc.with_name(f"{ctx.id}-light-{w}x{h}.png"), w, h)
    # Hex, the HUD design: a notched frame, the mark in its dial, leaders out
    # to the readouts. Each screen shape gets its own drawing, never cropped.
    for name, light in (("hex", False), ("hex-light", True)):
        for w, h in HEX_SIZES:
            hsrc = ctx.write(f"usr/share/backgrounds/{ctx.id}/{ctx.id}-{name}-{w}x{h}.svg", hex_wallpaper(w, h, light))
            rasterise(hsrc, hsrc.with_name(f"{ctx.id}-{name}-{w}x{h}.png"), w, h)
            # The interface alone (frame, dial, leaders, grid) on a clear
            # ground: the Hex wallpaper (org.cybroid.hex) draws it over a
            # picture the person chose, so their picture never hides Hex.
            usrc = ctx.write(f"usr/share/backgrounds/{ctx.id}/{ctx.id}-{name}-hud-{w}x{h}.svg", hex_wallpaper(w, h, light, hud=True))
            rasterise(usrc, usrc.with_name(f"{ctx.id}-{name}-hud-{w}x{h}.png"), w, h)


# Hex's layout, in units of the picture's height (u = H / 1080). The desktop
# widgets are placed to the same numbers by cybroid-appearance (keep them in
# step): each of the dial's six leaders ends beside one readout.
# Every common screen shape gets its own drawing, so the frame is never cut
# off: 16:9, 16:10, 4:3, 5:4, the two ultrawides (21:9, 32:9) and a portrait
# screen. The desktop shows the one nearest the screen's shape, in the
# smallest size at least as wide (cybroid-appearance and the widgets pick it
# the same way: hexPick). Keep this list in step with theirs.
HEX_SIZES = (
    (1920, 1080), (2560, 1440), (3840, 2160),  # 16:9
    (1920, 1200), (2560, 1600),  # 16:10
    (1600, 1200), (1280, 1024),  # 4:3, 5:4
    (2560, 1080), (3440, 1440), (5120, 1440),  # 21:9, 32:9
    (1080, 1920),  # portrait
)
HEX_WIDTH = 1800  # the design's unit u is H/1080, smaller on narrow screens: W/1800
HEX_CY = 530      # the dial's centre, from the top (10 above the middle)
HEX_DIAG = 127    # where the four slanting leaders leave the dial
HEX_ELBOW = 288   # where they turn level
HEX_SIDE = 300    # where the two level leaders leave it
HEX_END = 440     # where every leader ends, from the centre line


def hex_wallpaper(W: int = 1920, H: int = 1080, light: bool = False, hud: bool = False) -> str:
    """CybroidOS Hex's wallpaper: a notched frame round the screen, the CIT mark
    alone in a dial, and six leaders out to where the desktop's readouts
    sit. Drawn here rather than from a template: it is all geometry, and each
    screen shape (16:9, 16:10) gets its own so nothing is cropped. Hex Light
    is the same drawing in the light palette (HEX_LIGHT). With hud, the
    ground is left clear: the interface alone, to lay over another picture."""
    # On screens narrower than 16:10 the dial and its leaders shrink, so the
    # readout columns beside them stay wide enough to read.
    u = min(H / 1080, W / HEX_WIDTH)
    cx, cy = W / 2, H / 2 + (HEX_CY - 540) * u
    f = lambda v: f"{v:.1f}"
    out = [
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}">',
        "<defs>",
        f'<radialGradient id="bg" gradientUnits="userSpaceOnUse" cx="{f(cx)}" cy="{f(cy)}" r="{f(min(W, H * 16 / 9) * 0.62)}">'
        '<stop offset="0" stop-color="#0d1c44"/><stop offset=".5" stop-color="#071027"/><stop offset="1" stop-color="#030713"/></radialGradient>',
        f'<pattern id="grid" width="{f(32 * u)}" height="{f(32 * u)}" patternUnits="userSpaceOnUse">'
        f'<path d="M{f(32 * u)} 0H0V{f(32 * u)}" fill="none" stroke="#1ccbff" stroke-opacity=".035" stroke-width="1"/></pattern>',
        '<linearGradient id="cy" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#8fe6ff"/><stop offset="1" stop-color="#1ccbff"/></linearGradient>',
        '<linearGradient id="mk" gradientUnits="userSpaceOnUse" x1="170" y1="640" x2="640" y2="110">'
        # The mark keeps its own colours in both appearances (upper case, so
        # Hex Light's colour map below passes them by).
        '<stop offset="0" stop-color="#3A7CFF"/><stop offset=".55" stop-color="#2C9DFF"/><stop offset="1" stop-color="#1CCBFF"/></linearGradient>',
        '<radialGradient id="floor"><stop offset="0" stop-color="#3a7cff" stop-opacity=".55"/>'
        '<stop offset=".4" stop-color="#1ccbff" stop-opacity=".12"/><stop offset="1" stop-color="#1ccbff" stop-opacity="0"/></radialGradient>',
        "</defs>",
    ]
    if not hud:
        out.append(f'<rect width="{W}" height="{H}" fill="url(#bg)"/>')
    out.append(f'<rect width="{W}" height="{H}" fill="url(#grid)"/>')
    # The frame: notched under the top bar's tab, at both sides and above the
    # dock, with lit corners. The top bar covers the top 30 or so pixels.
    e, top, bot = 20 * u, 30 + 22 * u, H - 20 * u
    k, n = 24 * u, 20 * u  # corner cut, notch depth
    tn, bn, sn = 200 * u, 264 * u, 45 * u  # half-widths of the notches
    frame = (
        f"M{f(e + k)} {f(top)} H{f(cx - tn - n)} L{f(cx - tn)} {f(top + n)} H{f(cx + tn)} L{f(cx + tn + n)} {f(top)} "
        f"H{f(W - e - k)} L{f(W - e)} {f(top + k)} V{f(cy - sn - 10 * u)} L{f(W - e - 10 * u)} {f(cy - sn)} "
        f"V{f(cy + sn)} L{f(W - e)} {f(cy + sn + 10 * u)} V{f(bot - k)} L{f(W - e - k)} {f(bot)} "
        f"H{f(cx + bn + 16 * u)} L{f(cx + bn)} {f(bot - 16 * u)} H{f(cx - bn)} L{f(cx - bn - 16 * u)} {f(bot)} "
        f"H{f(e + k)} L{f(e)} {f(bot - k)} V{f(cy + sn + 10 * u)} L{f(e + 10 * u)} {f(cy + sn)} "
        f"V{f(cy - sn)} L{f(e)} {f(cy - sn - 10 * u)} V{f(top + k)} Z"
    )
    out.append(f'<path d="{frame}" fill="none" stroke="#1d3266" stroke-width="{f(1.5 * u)}"/>')
    L1, L2 = 160 * u, 80 * u
    lit = (
        f"M{f(e)} {f(top + k + L2)} V{f(top + k)} L{f(e + k)} {f(top)} H{f(e + k + L1)} "
        f"M{f(W - e - k - L1)} {f(top)} H{f(W - e - k)} L{f(W - e)} {f(top + k)} V{f(top + k + L2)} "
        f"M{f(e)} {f(bot - k - L2)} V{f(bot - k)} L{f(e + k)} {f(bot)} H{f(e + k + L1)} "
        f"M{f(W - e - k - L1)} {f(bot)} H{f(W - e - k)} L{f(W - e)} {f(bot - k)} V{f(bot - k - L2)}"
    )
    out.append(f'<path d="{lit}" fill="none" stroke="#1ccbff" stroke-width="{f(2 * u)}"/>')
    for x, y in ((e + 32 * u, top + 32 * u), (W - e - 32 * u, top + 32 * u), (e + 32 * u, bot - 32 * u), (W - e - 32 * u, bot - 32 * u)):
        out.append(f'<circle cx="{f(x)}" cy="{f(y)}" r="{f(6 * u)}" fill="#030713" stroke="#1ccbff" stroke-width="{f(1.5 * u)}"/>')
    # The tab under the top bar, in the top notch: a small hexagon between two
    # rules, the mark of the design.
    tw, th = 136 * u, top + 10 * u
    out.append(
        f'<path d="M{f(cx - tw)} 0 H{f(cx + tw)} L{f(cx + tw - 16 * u)} {f(th)} H{f(cx - tw + 16 * u)} Z" fill="#0a1532"/>'
    )
    hx = lambda r, x0, y0: " ".join(
        f"{f(x0 + r * c)},{f(y0 + r * s)}" for c, s in ((0, -1), (0.866, -0.5), (0.866, 0.5), (0, 1), (-0.866, 0.5), (-0.866, -0.5))
    )
    ty = th - 14 * u
    out.append(f'<polygon points="{hx(7 * u, cx, ty)}" fill="#1ccbff"/>')
    out.append(
        f'<path d="M{f(cx - 80 * u)} {f(ty)} H{f(cx - 18 * u)} M{f(cx + 18 * u)} {f(ty)} H{f(cx + 80 * u)}" '
        f'stroke="#3d5fa8" stroke-width="{f(1.5 * u)}"/>'
    )
    # A light on the floor under the dial.
    out.append(f'<ellipse cx="{f(cx)}" cy="{f(cy + 358 * u)}" rx="{f(480 * u)}" ry="{f(29 * u)}" fill="url(#floor)"/>')
    # Six leaders from the dial to the readouts' places.
    d, el, sd, end = HEX_DIAG * u, HEX_ELBOW * u, HEX_SIDE * u, HEX_END * u
    lead, starts, ends = [], [], []
    for sx in (-1, 1):
        for sy in (-1, 1):
            lead.append(f"M{f(cx + sx * d)} {f(cy + sy * d)} L{f(cx + sx * el)} {f(cy + sy * el)} H{f(cx + sx * end)}")
            starts.append((cx + sx * d, cy + sy * d, 6))
            ends.append((cx + sx * end, cy + sy * el))
        lead.append(f"M{f(cx + sx * sd)} {f(cy)} H{f(cx + sx * end)}")
        starts.append((cx + sx * sd, cy, 5))
        ends.append((cx + sx * end, cy))
    out.append(f'<path d="{" ".join(lead)}" fill="none" stroke="#3d5fa8" stroke-width="{f(1.5 * u)}"/>')
    for x, y in ends:
        out.append(f'<circle cx="{f(x)}" cy="{f(y)}" r="{f(4 * u)}" fill="#5f8fe0"/>')
    # The dial: rings and a hexagon for ornament, the mark alone inside with
    # nothing behind it.
    k2 = 1.2 * u
    g = [f'<g transform="translate({f(cx)} {f(cy)}) scale({k2:.4f})" fill="none">']
    g += [
        '<circle r="250" stroke="#2a4686" stroke-width="1.5" stroke-dasharray="330 62" transform="rotate(-70)"/>',
        '<circle r="226" stroke="#3d5fa8" stroke-width="8" stroke-dasharray="1.5 10.33" opacity=".7"/>',
        '<circle r="198" stroke="#0f1e45" stroke-width="20"/>',
        '<circle r="198" stroke="url(#cy)" stroke-width="20" stroke-dasharray="250 1000" transform="rotate(-110)" opacity=".9"/>',
        '<circle r="198" stroke="#3a7cff" stroke-width="20" stroke-dasharray="18 6 18 6 18 6 18 6 18 6 18 2000" transform="rotate(20)" opacity=".7"/>',
        '<circle r="198" stroke="#3a7cff" stroke-width="20" stroke-dasharray="18 6 18 6 18 6 18 6 18 6 18 2000" transform="rotate(200)" opacity=".7"/>',
        '<circle r="212" stroke="#1ccbff" stroke-width="2" stroke-dasharray="250 1082" transform="rotate(-110)"/>',
        '<circle r="166" stroke="#2a4686" stroke-width="1.5" stroke-dasharray="120 54"/>',
        '<polygon points="0,-150 130,-75 130,75 0,150 -130,75 -130,-75" stroke="#1d3266" stroke-width="1.5"/>',
        "</g>",
    ]
    out += g
    for x, y, r in starts:
        out.append(f'<circle cx="{f(x)}" cy="{f(y)}" r="{f(r * u)}" fill="#8fb4ee"/>')
    # The CIT mark (784 units), in its own colours, straight on the
    # wallpaper. Centred by eye: its outline is centred at (374, 383) in the
    # mark's units, its C's circle at (420, 378); centring the outline made it
    # look to the right, centring the circle to the left, so it sits halfway.
    s = 0.3 * k2
    out.append(f'<g transform="translate({f(cx - 397 * s)} {f(cy - 380 * s)}) scale({s:.4f})" fill="none">')
    for dd in ("M447.8 151.7 A228 228 0 0 0 253.3 533.5", "M264.5 544.7 A228 228 0 0 0 584.0 536.4", "M463.5 154.2 A228 228 0 0 1 589.4 225.4"):
        out.append(f'<path d="{dd}" stroke="url(#mk)" stroke-width="85"/>')
    out.append(
        '<g stroke="#18d8ff" stroke-width="8" stroke-linecap="round"><path d="M215.9 151.3 A305 305 0 0 1 624.1 151.3"/>'
        '<path d="M167.1 207.4 A305 305 0 0 0 115.2 367.4"/><path d="M120.6 436.2 A305 305 0 0 0 377.6 680.0"/>'
        '<path d="M446.6 681.8 A305 305 0 0 0 628.0 601.1"/><path d="M368.0 235.2 A152 152 0 0 0 363.1 518.9"/></g>'
    )
    out.append(
        '<g fill="#18d8ff">'
        + "".join(
            f'<circle cx="{x}" cy="{y}" r="16"/>'
            for x, y in ((215.9, 151.3), (624.1, 151.3), (167.1, 207.4), (120.6, 436.2), (377.6, 680), (446.6, 681.8), (628, 601.1), (368, 235.2), (363.1, 518.9))
        )
        + "</g></g>"
    )
    # Two strips along the bottom edge: chevrons at the left, a bar code at
    # the right (the HUD's instrument marks; no text, so no font is needed).
    by = bot - 34 * u
    chev = " ".join(
        f"M{f(e + 66 * u + i * 10 * u)} {f(by)} l{f(5 * u)} {f(4 * u)} l{f(-5 * u)} {f(4 * u)}" for i in range(4)
    )
    out.append(f'<path d="{chev}" fill="none" stroke="#1ccbff" stroke-width="{f(1.6 * u)}"/>')
    bw, bx = 190 * u, W - e - 66 * u - 190 * u
    out.append(
        f'<rect x="{f(bx)}" y="{f(by - 6 * u)}" width="{f(bw)}" height="{f(20 * u)}" fill="none" stroke="#1ccbff" stroke-width="{f(u)}"/>'
    )
    pat, x = (2, 3, 4, 2, 1, 4), bx + 4 * u
    i = 0
    while x < bx + bw - 6 * u:
        w = pat[i % len(pat)] * u
        if i % 2 == 0:
            out.append(f'<rect x="{f(x)}" y="{f(by - 3 * u)}" width="{f(w)}" height="{f(14 * u)}" fill="{"#8fe6ff" if i % 4 == 0 else "#1ccbff"}"/>')
        x += w
        i += 1
    out.append("</svg>")
    svg = "\n".join(out) + "\n"
    if light:
        svg = svg.replace('stroke-opacity=".035"', 'stroke-opacity=".09"')
        # A softer light under the dial: on a light ground it read as a shadow.
        svg = svg.replace('stop-color="#3a7cff" stop-opacity=".55"', 'stop-color="#ffffff" stop-opacity=".55"')
        svg = re.sub("|".join(HEX_LIGHT), lambda m: HEX_LIGHT[m.group(0)], svg)
    return svg


# Hex Light: each of Hex's colours and its light counterpart (the design's
# Hex // Light palette: ink #0b1634, accent #1f5fe0, hairlines #c9d5ea).
HEX_LIGHT = {
    # ground: a clear sky blue, deeper at the edges (Horizon Light's lesson:
    # near-white looked washed out)
    "#0d1c44": "#e3ecfc", "#071027": "#b4cbf3", "#030713": "#86a9e6",
    "#1ccbff": "#1f5fe0", "#8fe6ff": "#0b8fc4", "#18d8ff": "#0b8fc4",  # accents
    "#1d3266": "#7d9bd3", "#2a4686": "#9fb8e6", "#3d5fa8": "#6f8cc4", "#0f1e45": "#d6e3fa",  # lines
    "#0a1532": "#d6e4fa", "#5f8fe0": "#1f5fe0", "#8fb4ee": "#33405f",  # tab (the bar's blue), dots
}


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
