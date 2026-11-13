#!/usr/bin/env python3
"""Dark app icons for CybroidOS's Dark appearance (cybroid-icons).

WhiteSur's app icons are the same in its light and dark sets. macOS draws
dark versions in Dark mode: a white tile turns dark and the symbol keeps its
colour; tiles that already have a colour stay. This does the same: an icon
whose tile is light (sampled just inside its edge, rendered with
rsvg-convert) has its light, low-saturation colours (the tile and its pale
gradients) turned a dark navy grey of matching depth, in vector fills and in
the pictures WhiteSur layers in. Every other icon is left as it is.

    tools/icons-dark.py <icons dir>   # reads WhiteSur/apps/scalable,
                                      # writes WhiteSur-dark/apps/scalable

Run on the installed themes (the cybroid-icons build, after install.sh). WhiteSur's
dark set has no app icons of its own (its apps folder links to the light one).
"""

import base64
import colorsys
import io
import os
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

from PIL import Image

LIGHT = 0.80  # lightness from which a colour counts as the tile's
CHROMA = 48  # and the most its channels may differ (of 255): near-white
# tiles carry a faint tint, which HLS saturation calls strong at this
# lightness


def darken_rgb(r, g, b):
    """A light, near-grey colour -> a dark navy grey; others unchanged."""
    h, l, s = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
    if l < LIGHT or max(r, g, b) - min(r, g, b) > CHROMA:
        return None
    # White -> 0.16, the palest greys a little lighter, keeping their order.
    nl = 0.16 + (1.0 - l) * 0.9
    nr, ng, nb = colorsys.hls_to_rgb(0.62, nl, 0.18)  # a touch of CybroidOS navy
    return round(nr * 255), round(ng * 255), round(nb * 255)


HEX = re.compile(r"#([0-9a-fA-F]{6}|[0-9a-fA-F]{3})\b")


def darken_hex(m):
    v = m.group(1)
    if len(v) == 3:
        v = "".join(c * 2 for c in v)
    r, g, b = (int(v[i : i + 2], 16) for i in (0, 2, 4))
    d = darken_rgb(r, g, b)
    return m.group(0) if d is None else "#%02x%02x%02x" % d


NAMED = re.compile(r'(fill|stop-color|color)(=|:)(\s*"?)(white)\b')


def darken_png(data):
    im = Image.open(io.BytesIO(data)).convert("RGBA")
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            d = darken_rgb(r, g, b)
            if d is not None:
                px[x, y] = (*d, a)
    out = io.BytesIO()
    im.save(out, "PNG", optimize=True)
    return out.getvalue()


PNG = re.compile(r"data:image/png;base64,([A-Za-z0-9+/=\s]+)")


def darken_svg(text):
    text = HEX.sub(darken_hex, text)
    text = NAMED.sub(lambda m: f"{m.group(1)}{m.group(2)}{m.group(3)}#292e3b", text)
    return PNG.sub(
        lambda m: "data:image/png;base64," + base64.b64encode(darken_png(base64.b64decode(re.sub(r"\s", "", m.group(1))))).decode(),
        text,
    )


def light_tile(path):
    """True when the icon's tile, just inside its edge, is light and grey."""
    with tempfile.TemporaryDirectory() as t:
        png = os.path.join(t, "i.png")
        r = subprocess.run(["rsvg-convert", "-w", "64", "-h", "64", str(path), "-o", png], capture_output=True)
        if r.returncode:
            return False
        im = Image.open(png).convert("RGBA")
    light = 0
    for x, y in ((32, 9), (9, 32), (55, 32), (32, 52), (14, 14), (50, 14)):
        r, g, b, a = im.getpixel((x, y))
        if a > 200 and darken_rgb(r, g, b) is not None:
            light += 1
    return light >= 4


def main(root):
    root = pathlib.Path(root)
    src = root / "WhiteSur/apps/scalable"
    # WhiteSur-dark's (and -light's) app folders link to WhiteSur's own (the
    # apps folder or the scalable folder in it): the dark set gets copies of
    # its own first, or the dark icons would land in the shared folder and
    # show in Light too.
    dst = root / "WhiteSur-dark/apps/scalable"
    for d in (dst.parent, dst):
        if d.is_symlink():
            real = d.resolve()
            d.unlink()
            shutil.copytree(real, d, symlinks=True)
    dst.mkdir(parents=True, exist_ok=True)
    assert not any(p.is_symlink() for p in (dst, dst.parent)), "the dark set must own its folder"
    done = {}
    made = 0
    for f in sorted(src.iterdir()):
        if f.suffix != ".svg":
            continue
        out = dst / f.name
        real = f.resolve()
        if dst in real.parents or real.parent == dst:
            real = (src / f.name).resolve()
        if real not in done:
            try:
                done[real] = darken_svg(real.read_text()) if light_tile(real) else None
            except Exception as e:  # a broken icon stays light, never fails the build
                print(f"icons-dark: {f.name}: {e}", file=sys.stderr)
                continue
        if done.get(real) is None:
            continue  # a coloured tile: the same in Dark
        if out.is_symlink() or out.exists():
            out.unlink()
        out.write_text(done[real])
        made += 1
    print(f"icons-dark: {made} dark app icons from {sum(v is not None for v in done.values())} drawings")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
