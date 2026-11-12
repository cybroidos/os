#!/usr/bin/env python3
"""Generates the CIT-OS Horizon Plasma Style (citos-plasma).

A Plasma Style draws panels, the dock, popups, tooltips and highlights from
SVG "frames": nine named pieces (corners, edges, centre) Plasma stretches to
any size, plus hint rects for the content margins and mask pieces for the
blur behind. Everything here comes from a few numbers (radius, fill, edge),
so the look is tuned in one place. Elements this style doesn't draw fall
back to Plasma's default style.

    tools/plasma-style.py <out>   # writes usr/share/plasma/desktoptheme/citos{,-light}/
"""

import json
import pathlib
import sys

NAVY = (14, 24, 58)
GLASS = (34, 52, 108)
ACCENT = (28, 203, 255)
BLUE = (58, 124, 255)
WHITE = (255, 255, 255)
AMBER = (240, 166, 60)


def rgba(c, a):
    return f"rgb({c[0]},{c[1]},{c[2]})", f"{a:.3f}"


class Sheet:
    """One SVG holding many elements, each at its own place."""

    def __init__(self):
        self.parts = []
        self.y = 0

    def add(self, xml):
        self.parts.append(xml)

    def svg(self):
        h = self.y + 10
        body = "\n".join(self.parts)
        return (
            '<?xml version="1.0" encoding="UTF-8"?>\n'
            f'<svg xmlns="http://www.w3.org/2000/svg" width="400" height="{h}" viewBox="0 0 400 {h}">\n'
            f"{body}\n</svg>\n"
        )

    def frame(self, prefix, r, fill, alpha, edge=None, edge_alpha=0.0, margins=(6, 6, 6, 6), mask=True):
        """Adds a nine-piece frame (prefix "" for a plain one), its margins and mask."""
        p = f"{prefix}-" if prefix else ""
        x0, y0 = 10, self.y + 10
        w = 4  # stretched pieces' length
        col, op = rgba(fill, alpha)
        ecol, eop = rgba(edge or WHITE, edge_alpha)

        def piece(pid, x, y, shape, stroke=None):
            g = [f'<g id="{pid}">', f'<path d="{shape}" fill="{col}" fill-opacity="{op}"/>']
            if stroke and edge_alpha > 0:
                g.append(f'<path d="{stroke}" fill="none" stroke="{ecol}" stroke-opacity="{eop}" stroke-width="1"/>')
            g.append("</g>")
            self.add("".join(g))

        def mpiece(pid, shape):
            self.add(f'<path id="{pid}" d="{shape}" fill="#000000"/>')

        X, Y = x0, y0
        # Corners: quarter discs, the edge as an arc just inside.
        tl = f"M{X},{Y + r} A{r},{r} 0 0 1 {X + r},{Y} L{X + r},{Y + r} Z"
        tl_s = f"M{X + 0.5},{Y + r} A{r - 0.5},{r - 0.5} 0 0 1 {X + r},{Y + 0.5}"
        tx = X + r + w
        tr = f"M{tx},{Y} A{r},{r} 0 0 1 {tx + r},{Y + r} L{tx},{Y + r} Z"
        tr_s = f"M{tx},{Y + 0.5} A{r - 0.5},{r - 0.5} 0 0 1 {tx + r - 0.5},{Y + r}"
        by = Y + r + w
        bl = f"M{X + r},{by + r} A{r},{r} 0 0 1 {X},{by} L{X + r},{by} Z"
        bl_s = f"M{X + r},{by + r - 0.5} A{r - 0.5},{r - 0.5} 0 0 1 {X + 0.5},{by}"
        br = f"M{tx + r},{by} A{r},{r} 0 0 1 {tx},{by + r} L{tx},{by} Z"
        br_s = f"M{tx + r - 0.5},{by} A{r - 0.5},{r - 0.5} 0 0 1 {tx},{by + r - 0.5}"
        top = f"M{X + r},{Y} h{w} v{r} h{-w} Z"
        top_s = f"M{X + r},{Y + 0.5} h{w}"
        bottom = f"M{X + r},{by} h{w} v{r} h{-w} Z"
        bottom_s = f"M{X + r},{by + r - 0.5} h{w}"
        left = f"M{X},{Y + r} h{r} v{w} h{-r} Z"
        left_s = f"M{X + 0.5},{Y + r} v{w}"
        right = f"M{tx},{Y + r} h{r} v{w} h{-r} Z"
        right_s = f"M{tx + r - 0.5},{Y + r} v{w}"
        center = f"M{X + r},{Y + r} h{w} v{w} h{-w} Z"

        piece(p + "topleft", X, Y, tl, tl_s)
        piece(p + "topright", tx, Y, tr, tr_s)
        piece(p + "bottomleft", X, by, bl, bl_s)
        piece(p + "bottomright", tx, by, br, br_s)
        piece(p + "top", X + r, Y, top, top_s)
        piece(p + "bottom", X + r, by, bottom, bottom_s)
        piece(p + "left", X, Y + r, left, left_s)
        piece(p + "right", tx, Y + r, right, right_s)
        piece(p + "center", X + r, Y + r, center)

        # Edges stretch rather than tile: tiled translucent pieces show seams.
        self.add(f'<rect id="{p}hint-stretch-borders" x="{tx + r + 4}" y="{Y + r + w + 2}" width="2" height="2" fill="none"/>')

        # Margins: how far content sits from each edge.
        mt, ml, mr, mb = margins
        hx = tx + r + 20
        for side, size in (("top", mt), ("left", ml), ("right", mr), ("bottom", mb)):
            hw, hh = (size, 4) if side in ("left", "right") else (4, size)
            self.add(f'<rect id="{p}hint-{side}-margin" x="{hx}" y="{Y}" width="{hw}" height="{hh}" fill="none"/>')
            hx += 20

        self.y = by + r + 10
        if mask:
            X, Y = x0 + 200, y0
            tx2, by2 = X + r + w, Y + r + w
            mpiece(p + "mask-topleft", f"M{X},{Y + r} A{r},{r} 0 0 1 {X + r},{Y} L{X + r},{Y + r} Z")
            mpiece(p + "mask-topright", f"M{tx2},{Y} A{r},{r} 0 0 1 {tx2 + r},{Y + r} L{tx2},{Y + r} Z")
            mpiece(p + "mask-bottomleft", f"M{X + r},{by2 + r} A{r},{r} 0 0 1 {X},{by2} L{X + r},{by2} Z")
            mpiece(p + "mask-bottomright", f"M{tx2 + r},{by2} A{r},{r} 0 0 1 {tx2},{by2 + r} L{tx2},{by2} Z")
            mpiece(p + "mask-top", f"M{X + r},{Y} h{w} v{r} h{-w} Z")
            mpiece(p + "mask-bottom", f"M{X + r},{by2} h{w} v{r} h{-w} Z")
            mpiece(p + "mask-left", f"M{X},{Y + r} h{r} v{w} h{-r} Z")
            mpiece(p + "mask-right", f"M{tx2},{Y + r} h{r} v{w} h{-r} Z")
            mpiece(p + "mask-center", f"M{X + r},{Y + r} h{w} v{w} h{-w} Z")


# alpha by variant: translucent (blur behind), default, opaque (no compositing)
VARIANTS = {"translucent": 0.72, "": 0.9, "opaque": 1.0}

# The two styles: CIT-OS Horizon (dark) and CIT-OS Horizon Light. Each names
# the bar over the wallpaper (colour, alpha), the bar when a window is
# maximised and the tint for hovered rows. main() writes one style per entry.
STYLES = {
    "citos": dict(
        name="CIT-OS Horizon", desc="CIT-OS Horizon: a clear top bar, solid navy popups",
        bar=(WHITE, 0.05), bar_default=(NAVY, 0.55), bar_solid=NAVY, hover=(WHITE, 0.08),
    ),
    "citos-light": dict(
        name="CIT-OS Horizon Light", desc="CIT-OS Horizon Light: a frosted white top bar, white popups",
        bar=((246, 248, 252), 0.82), bar_default=((246, 248, 252), 0.9), bar_solid=(240, 243, 248),
        hover=((14, 24, 58), 0.06),
    ),
    # Hex, the HUD design in CIT's colours: a deep navy bar, popups cut at
    # the top-left and bottom-right corners (Hangar's panels), cyan hovers.
    "citos-hex": dict(
        name="CIT-OS Hex", desc="CIT-OS Hex: the HUD design, deep navy and cyan with cut corners",
        bar=((6, 12, 30), 0.94), bar_default=((6, 12, 30), 0.96), bar_solid=(6, 12, 30),
        hover=((28, 203, 255), 0.14), radius=14, tip_radius=8, bevel=True, shadow=0.14,
    ),
    # Hex Light: the same shapes in daylight, a near-white bar, blue hovers.
    "citos-hex-light": dict(
        name="CIT-OS Hex Light", desc="CIT-OS Hex Light: the HUD design in daylight, white and CIT blue with cut corners",
        bar=((250, 252, 255), 0.94), bar_default=((250, 252, 255), 0.96), bar_solid=(250, 252, 255),
        hover=((31, 95, 224), 0.10), radius=14, tip_radius=8, bevel=True, shadow=0.08,
    ),
}
S = STYLES["citos"]


def popup(r, margins, pad, shadow_alpha, bevel=False):
    """Popups and tooltips at CIT-OS's radius, with a soft shadow.

    The layout follows Plasma's own Breeze dialog: a nine-piece frame with
    zero "hint-*-inset"s, a mask, and shadow pieces pad + r deep whose
    "shadow-hint-*-margin" and "shadow-hint-*-inset" are both pad. Without
    the insets Plasma placed the shadow wrongly (square boxes at the
    corners). Plain filled pieces, no outline: Plasma tiles the edges, and a
    hairline showed as stripes at the seams. The colour comes from the colour
    scheme (ColorScheme-Background), so one file serves Dark and Light."""
    w = 4  # stretched pieces' length
    parts = []
    add = parts.append
    fill = 'class="ColorScheme-Background" fill="currentColor"'

    # The frame at (10, 10).
    X, Y = 10, 10
    tx, by = X + r + w, Y + r + w

    def corner(pid, cx, cy, sx, sy, mask=False):
        # (cx, cy): the corner's centre of curvature; sx, sy: outwards.
        sweep = 1 if sx * sy > 0 else 0
        ox, oy = cx + sx * r, cy + sy * r
        if not bevel:
            shape = f"M{cx},{cy} L{ox},{cy} A{r},{r} 0 0 {sweep} {cx},{oy} Z"
        elif sx * sy > 0:
            # Hex: Hangar's cut panels, the top-left and bottom-right corners
            # chamfered...
            shape = f"M{cx},{cy} L{ox},{cy} L{cx},{oy} Z"
        else:
            # ...the other two square.
            shape = f"M{cx},{cy} L{ox},{cy} L{ox},{oy} L{cx},{oy} Z"
        if mask:
            return f'<path id="{pid}" d="{shape}" fill="#000000"/>'
        return f'<path id="{pid}" d="{shape}" {fill}/>'

    def frame(prefix, x, y, mask=False):
        X, Y = x, y
        tx, by = X + r + w, Y + r + w
        p = prefix
        add(corner(p + "topleft", X + r, Y + r, -1, -1, mask))
        add(corner(p + "topright", tx, Y + r, 1, -1, mask))
        add(corner(p + "bottomleft", X + r, by, -1, 1, mask))
        add(corner(p + "bottomright", tx, by, 1, 1, mask))
        for pid, x0, y0, ww, hh, edge in (
            ("top", X + r, Y, w, r, f"M{X + r},{Y + 0.5} h{w}"),
            ("bottom", X + r, by, w, r, f"M{X + r},{by + r - 0.5} h{w}"),
            ("left", X, Y + r, r, w, f"M{X + 0.5},{Y + r} v{w}"),
            ("right", tx, Y + r, r, w, f"M{tx + r - 0.5},{Y + r} v{w}"),
            ("center", X + r, Y + r, w, w, None),
        ):
            rect = f'x="{x0}" y="{y0}" width="{ww}" height="{hh}"'
            if mask:
                add(f'<rect id="{p}{pid}" {rect} fill="#000000"/>')
            else:
                add(f'<rect id="{p}{pid}" {rect} {fill}/>')

    frame("", X, Y)
    frame("mask-", X + 60, Y, mask=True)
    hx = X + 120
    mt, ml, mr, mb = margins
    for side, size in (("top", mt), ("left", ml), ("right", mr), ("bottom", mb)):
        hw, hh = (size, 4) if side in ("left", "right") else (4, size)
        add(f'<rect id="hint-{side}-margin" x="{hx}" y="{Y}" width="{hw}" height="{hh}" fill="none"/>')
        iw, ih = (1e-8, 4) if side in ("left", "right") else (4, 1e-8)
        add(f'<rect id="hint-{side}-inset" x="{hx}" y="{Y + 40}" width="{iw}" height="{ih}" fill="none"/>')
        hx += 20

    # The shadow at (10, 100): pieces d deep, darkest at the frame's edge.
    d = pad + r
    steps = 10
    a = 1 - (1 - shadow_alpha) ** (1 / steps)
    SX, SY = 10, 100
    stx, sby = SX + d + w, SY + d + w

    def layers(shape):
        return "".join(f'<path d="{shape(pad * (1 - i / steps))}" fill="#000000" fill-opacity="{a:.4f}"/>' for i in range(steps))

    def scorner(pid, cx, cy, sx, sy):
        sweep = 1 if sx * sy > 0 else 0

        def q(t):
            R = r + t
            if not bevel:
                return f"M{cx},{cy} L{cx + sx * R},{cy} A{R},{R} 0 0 {sweep} {cx},{cy + sy * R} Z"
            if sx * sy > 0:
                return f"M{cx},{cy} L{cx + sx * R},{cy} L{cx},{cy + sy * R} Z"
            return f"M{cx},{cy} L{cx + sx * R},{cy} L{cx + sx * R},{cy + sy * R} L{cx},{cy + sy * R} Z"

        add(f'<g id="{pid}">{layers(q)}</g>')

    scorner("shadow-topleft", SX + d, SY + d, -1, -1)
    scorner("shadow-topright", stx, SY + d, 1, -1)
    scorner("shadow-bottomleft", SX + d, sby, -1, 1)
    scorner("shadow-bottomright", stx, sby, 1, 1)
    add('<g id="shadow-top">' + layers(lambda t: f"M{SX + d},{SY + d} h{w} v{-(r + t)} h{-w} Z") + "</g>")
    add('<g id="shadow-bottom">' + layers(lambda t: f"M{SX + d},{sby} h{w} v{r + t} h{-w} Z") + "</g>")
    add('<g id="shadow-left">' + layers(lambda t: f"M{SX + d},{SY + d} v{w} h{-(r + t)} v{-w} Z") + "</g>")
    add('<g id="shadow-right">' + layers(lambda t: f"M{stx},{SY + d} v{w} h{r + t} v{-w} Z") + "</g>")
    add(f'<rect id="shadow-center" x="{SX + d}" y="{SY + d}" width="{w}" height="{w}" fill="none"/>')
    hx = stx + d + 20
    for side in ("top", "left", "right", "bottom"):
        hw, hh = (pad, 2) if side in ("left", "right") else (2, pad)
        add(f'<rect id="shadow-hint-{side}-margin" x="{hx}" y="{SY}" width="{hw}" height="{hh}" fill="none"/>')
        add(f'<rect id="shadow-hint-{side}-inset" x="{hx}" y="{SY + 30}" width="{hw}" height="{hh}" fill="none"/>')
        hx += 20

    h = sby + d + 20
    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        f'<svg xmlns="http://www.w3.org/2000/svg" width="400" height="{h}" viewBox="0 0 400 {h}">\n'
        '<style type="text/css" id="current-color-scheme">'
        ".ColorScheme-Background{color:#111b3d;}.ColorScheme-Text{color:#e8eefc;}</style>\n"
        + "\n".join(parts)
        + "\n</svg>\n"
    )


def panel(variant):
    """The top bar: nearly clear over the wallpaper (macOS's menu bar), solid
    navy when a window is maximised (Plasma's opaque variant)."""
    s = Sheet()
    if variant == "opaque":
        s.frame("", 1, S["bar_solid"], 1.0, None, 0, margins=(4, 8, 8, 4))
    elif variant == "translucent":
        s.frame("", 1, S["bar"][0], S["bar"][1], None, 0, margins=(4, 8, 8, 4))
    else:
        s.frame("", 1, S["bar_default"][0], S["bar_default"][1], None, 0, margins=(4, 8, 8, 4))
    return s.svg()


def tasks():
    """Task tiles in the dock: soft for running, cyan-tinted for the focused one."""
    s = Sheet()
    m = (5, 6, 6, 5)
    s.frame("normal", 12, WHITE, 0.07, WHITE, 0.06, margins=m, mask=False)
    s.frame("focus", 12, ACCENT, 0.20, ACCENT, 0.45, margins=m, mask=False)
    s.frame("hover", 12, WHITE, 0.13, WHITE, 0.10, margins=m, mask=False)
    s.frame("attention", 12, AMBER, 0.24, AMBER, 0.55, margins=m, mask=False)
    s.frame("minimized", 12, WHITE, 0.04, WHITE, 0.04, margins=m, mask=False)
    return s.svg()


def viewitem():
    """Rounded highlights in lists (the launcher, menus, the tray)."""
    s = Sheet()
    m = (4, 8, 8, 4)
    s.frame("hover", 8, S["hover"][0], S["hover"][1], None, 0, margins=m, mask=False)
    s.frame("selected", 8, BLUE, 0.32, BLUE, 0.4, margins=m, mask=False)
    s.frame("selected+hover", 8, BLUE, 0.42, BLUE, 0.5, margins=m, mask=False)
    s.frame("normal", 8, WHITE, 0.0, None, 0, margins=m, mask=False)
    return s.svg()


def main(out):
    global S
    for sid, S in STYLES.items():
        write(out, sid)


def write(out, sid):
    root = pathlib.Path(out) / "usr/share/plasma/desktoptheme" / sid
    meta = {
        "KPlugin": {
            "Authors": [{"Name": "Cybroid Institute of Technology", "Email": "citos@cybroid.com"}],
            "Description": S["desc"],
            "Id": sid,
            "License": "GPL-2.0-or-later",
            "Name": S["name"],
            "Version": "1.0",
            "Website": "https://cybroid.com",
        },
        "X-Plasma-API": "5.0",
    }
    files = {"metadata.json": json.dumps(meta, indent=4) + "\n"}
    files["plasmarc"] = (
        "[ContrastEffect]\nenabled=false\n\n"
        "[AdaptiveTransparency]\nenabled=true\n"
    )
    for variant, alpha in VARIANTS.items():
        base = f"{variant}/" if variant else ""
        files[f"{base}widgets/panel-background.svg"] = panel(variant or "default")
        # Popups at the radius of Control Centre's tiles and the cards (14),
        # tooltips a little tighter; both follow the colour scheme.
        # Hex keeps its shadows light (shadow): heavy ones muddied the design.
        sh = S.get("shadow", 0.30)
        files[f"{base}dialogs/background.svg"] = popup(S.get("radius", 14), (10, 10, 10, 10), 12, sh, S.get("bevel", False))
        files[f"{base}widgets/tooltip.svg"] = popup(S.get("tip_radius", 10), (6, 10, 10, 6), 8, sh * 0.7, S.get("bevel", False))
    files["widgets/tasks.svg"] = tasks()
    files["widgets/viewitem.svg"] = viewitem()
    for name, text in files.items():
        f = root / name
        f.parent.mkdir(parents=True, exist_ok=True)
        f.write_text(text)
    print(f"wrote {len(files)} files to {root}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
