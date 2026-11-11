#!/usr/bin/env python3
"""Generates the CIT-OS window decoration, an Aurorae theme (citos-plasma).

Windows get a title bar in the window's own navy (one surface with the app,
as on a Mac), a centred title, round coloured buttons on the left (close,
minimise, zoom; their symbol shows on hover) and a soft shadow that falls
lower than it rises. Corners are rounded at the same radius as the KDE
Rounded Corners effect (kwinrc [Round-Corners] Size), so the two agree.

Aurorae draws the decoration from SVG frames: nine named pieces stretched
around the window. The shadow lives in the padding outside the window, drawn
as rings that fade outwards; rings, not filled shapes, so nothing dark shows
where the effect rounds the window's bottom corners.

    tools/aurorae-theme.py <out>   # writes usr/share/aurorae/themes/CIT-OS{,-Light}/

Two themes from the same shapes: CIT-OS (navy, for CIT-OS Horizon) and
CIT-OS-Light (soft white, for CIT-OS Horizon Light).
"""

import gzip
import json
import pathlib
import sys

NAME = "CIT-OS"
R = 18  # corner radius: kwinrc [Round-Corners] Size
TITLE_H = 20  # title text row
EDGE_T, EDGE_B = 8, 8  # space above and below it
BAR = EDGE_T + TITLE_H + EDGE_B
# Shadow room around the window (left, top, right, bottom): it falls lower,
# as macOS's windows float well above the desktop.
PL, PT, PR, PB = 40, 24, 40, 56
LAYERS = 18
SHADOW = 0.30  # the soft shadow's strength (per variant)
HIGHLIGHT = (255, 255, 255, 0.10)  # the light line along the bar's top

ACTIVE_BAR = (17, 27, 61)  # [Colors:Window] BackgroundNormal of CITOSHorizon
INACTIVE_BAR = (14, 22, 52)
ACTIVE_TEXT = (232, 238, 252)
INACTIVE_TEXT = (138, 156, 196)

# name: (active bar, inactive bar, active text, inactive text); main() sets
# the globals above from each in turn.
VARIANTS = {
    "CIT-OS": ((17, 27, 61), (14, 22, 52), (232, 238, 252), (138, 156, 196), 0.34, (255, 255, 255, 0.10)),
    # [WM] of CITOSHorizonLight
    "CIT-OS-Light": ((236, 239, 245), (245, 246, 249), (22, 30, 52), (120, 130, 150), 0.22, (255, 255, 255, 0.9)),
}

BUTTONS = {  # file: (colour, symbol)
    "close": ((255, 98, 89), "x"),
    "minimize": ((245, 190, 79), "min"),
    "maximize": ((62, 214, 140), "max"),
    "restore": ((62, 214, 140), "restore"),
}


def rgb(c):
    return f"rgb({c[0]},{c[1]},{c[2]})"


def shadow_layers(strength):
    """(left, top, right, bottom spread, opacity) per ring, outermost first."""
    out = []
    for i in range(LAYERS):
        t = (i + 1) / LAYERS  # 1/L .. 1: how far out
        # Each ring adds a little; stacked, they fade from dark at the edge.
        a = strength * (1 - t) ** 2 * SHADOW
        out.append((PL * t, PT * t, PR * t, PB * t, a))
    # A tight, darker edge right at the window: its outline reads at once,
    # as on macOS, whatever lies behind.
    for d, a in ((2.5, 0.10), (1.2, 0.12)):
        out.append((d, d * 0.6, d, d * 1.4, a * strength))
    return out[::-1]


class Doc:
    def __init__(self):
        self.parts = []
        self.y = 0

    def add(self, s):
        self.parts.append(s)

    def svg(self, w=None):
        w = w or 600
        h = self.y + 10
        return (
            '<?xml version="1.0" encoding="UTF-8"?>\n'
            f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">\n'
            + "\n".join(self.parts)
            + "\n</svg>\n"
        )


def frame(doc, prefix, bar, strength):
    """One nine-piece decoration at doc.y, in model coordinates shifted there.

    The model: the window's frame starts at (PL, PT); the title bar is BAR
    tall; side and bottom borders are 0. Corner pieces are PL+R wide, so the
    rounding fits inside them; the window covers what lies under it.
    """
    oy = doc.y + 10
    ox = 10
    W = 4  # stretched pieces' length
    cw_l, cw_r = PL + R, PR + R  # corner widths
    top_h = PT + BAR  # top row height
    bot_h = PB + R  # bottom row height (overlaps the window by R)
    # Column x positions in the sheet: [left corner][W][right corner]
    xl, xm, xr = ox, ox + cw_l, ox + cw_l + W
    # Row y positions: [top row][W][bottom row]
    yt, ym, yb = oy, oy + top_h, oy + top_h + W
    layers = shadow_layers(strength)

    def g(pid, body):
        doc.add(f'<g id="{prefix}-{pid}">{body}</g>')

    def ring_corner(cx, cy, sx, sy, X0, Y0, X1, Y1, inner):
        """Rings around one corner. (cx, cy): the arc's centre in the piece;
        sx, sy: which way is outwards (-1 or 1); [X0,X1]x[Y0,Y1]: the piece."""
        s = []
        for dl, dt, dr, db, a in layers:
            ex = dl if sx < 0 else dr
            ey = dt if sy < 0 else db
            rx, ry = R + ex, R + ey
            # Outer: from the piece's inner edge along the shadow's edge,
            # round the corner, back along the other edge. Inner: the window.
            outer = quarter(cx, cy, rx, ry, sx, sy, X0, Y0, X1, Y1)
            s.append(
                f'<path d="{outer} {inner}" fill="#000000" fill-opacity="{a:.4f}" fill-rule="evenodd"/>'
            )
        return "".join(s)

    def quarter(cx, cy, rx, ry, sx, sy, X0, Y0, X1, Y1):
        # The part of an ellipse-cornered box that lies in the piece: from the
        # point on the vertical edge, round the arc, to the horizontal edge,
        # then along the piece's inner sides.
        px = cx + sx * rx  # the shadow's vertical edge
        py = cy + sy * ry  # its horizontal edge
        inner_x = X1 if sx < 0 else X0  # the piece's side towards the window
        inner_y = Y1 if sy < 0 else Y0
        # Path goes: (px, inner_y) -> (px, cy) -> arc -> (cx, py) -> (inner_x, py) -> (inner_x, inner_y)
        return (
            f"M{px:.2f},{inner_y:.2f} L{px:.2f},{cy:.2f} "
            f"A{rx:.2f},{ry:.2f} 0 0 {arc_sweep(sx, sy)} {cx:.2f},{py:.2f} "
            f"L{inner_x:.2f},{py:.2f} L{inner_x:.2f},{inner_y:.2f} Z"
        )

    def arc_sweep(sx, sy):
        # From the vertical edge to the horizontal one, going round outside.
        return {(-1, -1): 1, (1, -1): 0, (1, 1): 1, (-1, 1): 0}[(sx, sy)]

    def win_corner(cx, cy, sx, sy, X0, Y0, X1, Y1):
        """The window's own rounded corner inside the piece (cut from rings)."""
        return quarter(cx, cy, R, R, sx, sy, X0, Y0, X1, Y1)

    hl = f'fill="none" stroke="{rgb(HIGHLIGHT[:3])}" stroke-opacity="{HIGHLIGHT[3] * strength:.3f}" stroke-width="1"'

    def bar_corner(cx, cy, sx, X0, X1, y_top, y_bot):
        """The title bar's fill in a top corner piece: rounded at the top,
        with the highlight following the curve."""
        edge_x = cx + sx * R
        inner_x = X1 if sx < 0 else X0
        sweep = 1 if sx < 0 else 0
        r2 = R - 0.5
        return (
            f'<path d="M{edge_x:.2f},{y_bot:.2f} L{edge_x:.2f},{cy:.2f} '
            f"A{R},{R} 0 0 {sweep} {cx:.2f},{y_top:.2f} L{inner_x:.2f},{y_top:.2f} "
            f'L{inner_x:.2f},{y_bot:.2f} Z" fill="{rgb(bar)}"/>'
            f'<path d="M{cx + sx * r2:.2f},{cy + 4:.2f} L{cx + sx * r2:.2f},{cy:.2f} '
            f'A{r2},{r2} 0 0 {sweep} {cx:.2f},{y_top + 0.5:.2f} L{inner_x:.2f},{y_top + 0.5:.2f}" {hl}/>'
        )

    # --- top-left: rings around the corner, the window cut out, the bar.
    X0, Y0, X1, Y1 = xl, yt, xm, ym
    cx, cy = xl + PL + R, yt + PT + R
    inner = win_corner(cx, cy, -1, -1, X0, Y0, X1, Y1)
    body = ring_corner(cx, cy, -1, -1, X0, Y0, X1, Y1, inner)
    body += bar_corner(cx, cy, -1, X0, X1, yt + PT, Y1)
    g("topleft", body)

    # --- top: rings above, then the bar.
    body = "".join(
        f'<rect x="{xm}" y="{yt + PT - dt:.2f}" width="{W}" height="{dt:.2f}" fill="#000000" fill-opacity="{a:.4f}"/>'
        for dl, dt, dr, db, a in layers
    )
    body += f'<rect x="{xm}" y="{yt + PT}" width="{W}" height="{BAR}" fill="{rgb(bar)}"/>'
    body += f'<path d="M{xm},{yt + PT + 0.5} h{W}" {hl}/>'
    g("top", body)

    # --- top-right
    X0, Y0, X1, Y1 = xr, yt, xr + cw_r, ym
    cx, cy = xr, yt + PT + R
    inner = win_corner(cx, cy, 1, -1, X0, Y0, X1, Y1)
    body = ring_corner(cx, cy, 1, -1, X0, Y0, X1, Y1, inner)
    body += bar_corner(cx, cy, 1, X0, X1, yt + PT, Y1)
    g("topright", body)

    # --- left and right: rings beside the window.
    g("left", side_rings(layers, "left", xl, ym, xl + PL, yb) + f'<rect x="{xl}" y="{ym}" width="{cw_l}" height="{W}" fill="none"/>')
    g("right", side_rings(layers, "right", xr + R, ym, xr + cw_r, yb) + f'<rect x="{xr}" y="{ym}" width="{cw_r}" height="{W}" fill="none"/>')

    # --- bottom-left
    X0, Y0, X1, Y1 = xl, yb, xm, yb + bot_h
    cx, cy = xl + PL + R, yb
    inner = win_corner(cx, cy, -1, 1, X0, Y0, X1, Y1)
    g("bottomleft", ring_corner(cx, cy, -1, 1, X0, Y0, X1, Y1, inner))

    # --- bottom
    body = "".join(
        f'<rect x="{xm}" y="{yb + R:.2f}" width="{W}" height="{db:.2f}" fill="#000000" fill-opacity="{a:.4f}"/>'
        for dl, dt, dr, db, a in layers
    )
    g("bottom", body + f'<rect x="{xm}" y="{yb}" width="{W}" height="{bot_h}" fill="none"/>')

    # --- bottom-right
    X0, Y0, X1, Y1 = xr, yb, xr + cw_r, yb + bot_h
    cx, cy = xr, yb
    inner = win_corner(cx, cy, 1, 1, X0, Y0, X1, Y1)
    g("bottomright", ring_corner(cx, cy, 1, 1, X0, Y0, X1, Y1, inner))

    # --- centre: under the window, never seen.
    g("center", f'<rect x="{xm}" y="{ym}" width="{W}" height="{W}" fill="{rgb(bar)}"/>')

    doc.y = yb + bot_h + 10


def side_rings(layers, side, X0, Y0, X1, Y1):
    out = []
    for dl, dt, dr, db, a in layers:
        if side == "left":
            x, w = X1 - dl, dl
        else:
            x, w = X0, dr
        out.append(
            f'<rect x="{x:.2f}" y="{Y0:.2f}" width="{w:.2f}" height="{Y1 - Y0:.2f}" fill="#000000" fill-opacity="{a:.4f}"/>'
        )
    return "".join(out)


def maximized(doc, prefix, bar):
    """Maximised windows: a plain bar, no shadow, no rounding."""
    oy = doc.y + 10
    ox = 10
    W = 4
    for pid, x, y, w, h in (
        ("topleft", ox, oy, 1, BAR),
        ("top", ox + 1, oy, W, BAR),
        ("topright", ox + 1 + W, oy, 1, BAR),
        ("left", ox, oy + BAR, 1, W),
        ("center", ox + 1, oy + BAR, W, W),
        ("right", ox + 1 + W, oy + BAR, 1, W),
        ("bottomleft", ox, oy + BAR + W, 1, 1),
        ("bottom", ox + 1, oy + BAR + W, W, 1),
        ("bottomright", ox + 1 + W, oy + BAR + W, 1, 1),
    ):
        fill = rgb(bar) if pid.startswith("top") or pid == "center" else "none"
        doc.add(f'<rect id="{prefix}-{pid}" x="{x}" y="{y}" width="{w}" height="{h}" fill="{fill}"/>')
    doc.y = oy + BAR + W + 1 + 10


def decoration():
    d = Doc()
    frame(d, "decoration", ACTIVE_BAR, 1.0)
    frame(d, "decoration-inactive", INACTIVE_BAR, 0.6)
    maximized(d, "decoration-maximized", ACTIVE_BAR)
    maximized(d, "decoration-maximized-inactive", INACTIVE_BAR)
    return d.svg()


def symbol(kind, c):
    """A button's symbol, drawn on hover, in a dark shade of its colour."""
    dark = rgb(tuple(int(v * 0.35) for v in c))
    st = f'stroke="{dark}" stroke-width="1.6" stroke-linecap="round" fill="none"'
    m = 10
    if kind == "x":
        return f'<path d="M{m - 3},{m - 3} L{m + 3},{m + 3} M{m + 3},{m - 3} L{m - 3},{m + 3}" {st}/>'
    if kind == "min":
        return f'<path d="M{m - 3.5},{m} L{m + 3.5},{m}" {st}/>'
    if kind == "max":
        return f'<path d="M{m - 3.5},{m} L{m + 3.5},{m} M{m},{m - 3.5} L{m},{m + 3.5}" {st}/>'
    # restore: two small inward corners
    return f'<path d="M{m - 3.5},{m - 1} L{m - 1},{m - 1} L{m - 1},{m - 3.5} M{m + 3.5},{m + 1} L{m + 1},{m + 1} L{m + 1},{m + 3.5}" {st}/>'


def button(c, kind):
    """20x20 states side by side: a 13 px disc, its symbol on hover."""
    parts = []
    states = [
        ("active", c, 1.0, False),
        ("hover", c, 1.0, True),
        ("pressed", tuple(int(v * 0.8) for v in c), 1.0, True),
        ("inactive", (120, 136, 176), 0.45, False),
        ("hover-inactive", c, 1.0, True),
        ("pressed-inactive", tuple(int(v * 0.8) for v in c), 1.0, True),
        ("deactivated", (120, 136, 176), 0.3, False),
    ]
    x = 0
    for state, col, op, sym in states:
        inner = (
            f'<rect x="0" y="0" width="20" height="20" fill="none"/>'
            f'<circle cx="10" cy="10" r="6.5" fill="{rgb(col)}" fill-opacity="{op}"/>'
            f'<circle cx="10" cy="10" r="6.1" fill="none" stroke="#000000" stroke-opacity="0.18" stroke-width="0.8"/>'
        )
        if sym:
            inner += symbol(kind, c)
        parts.append(f'<g id="{state}-center" transform="translate({x},0)">{inner}</g>')
        x += 24
    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{x}" height="20" viewBox="0 0 {x} 20">\n'
        + "\n".join(parts)
        + "\n</svg>\n"
    )


def rc():
    t = ACTIVE_TEXT
    i = INACTIVE_TEXT
    return f"""[General]
ActiveTextColor={t[0]},{t[1]},{t[2]},255
InactiveTextColor={i[0]},{i[1]},{i[2]},255
TitleAlignment=Center
TitleVerticalAlignment=Center
Animation=120
UseTextShadow=false
HaloActive=false
HaloInactive=false

[Layout]
BorderLeft=0
BorderRight=0
BorderBottom=0
TitleEdgeTop={EDGE_T}
TitleEdgeBottom={EDGE_B}
TitleEdgeLeft=12
TitleEdgeRight=12
TitleEdgeTopMaximized={EDGE_T - 2}
TitleEdgeBottomMaximized={EDGE_B - 2}
TitleEdgeLeftMaximized=10
TitleEdgeRightMaximized=10
TitleBorderLeft=12
TitleBorderRight=12
TitleHeight={TITLE_H}
ButtonWidth=20
ButtonHeight=20
ButtonSpacing=1
ButtonMarginTop=0
ButtonMarginTopMaximized=0
ExplicitButtonSpacer=8
PaddingTop={PT}
PaddingBottom={PB}
PaddingLeft={PL}
PaddingRight={PR}
"""


def main(out):
    global NAME, ACTIVE_BAR, INACTIVE_BAR, ACTIVE_TEXT, INACTIVE_TEXT, SHADOW, HIGHLIGHT
    for NAME, (ACTIVE_BAR, INACTIVE_BAR, ACTIVE_TEXT, INACTIVE_TEXT, SHADOW, HIGHLIGHT) in VARIANTS.items():
        write(out)


def write(out):
    root = pathlib.Path(out) / "usr/share/aurorae/themes" / NAME
    root.mkdir(parents=True, exist_ok=True)
    (root / "decoration.svg").unlink(missing_ok=True)
    # Plasma 6 finds Aurorae themes as KPackages (KWin/Aurorae), by metadata.json.
    meta = {
        "KPackageStructure": "KWin/Aurorae",
        "KPlugin": {
            "Authors": [{"Name": "Cybroid Institute of Technology", "Email": "citos@cybroid.com"}],
            "Description": "Round coloured buttons, a centred title and a soft shadow",
            "Id": NAME,
            "License": "GPL-2.0-or-later",
            "Name": NAME,
            "Version": "1.0",
            "Website": "https://cybroid.com",
        },
        "X-Plasma-API-Minimum-Version": "6.0",
    }
    (root / "metadata.json").write_text(json.dumps(meta, indent=4) + "\n")
    (root / f"{NAME}rc").write_text(rc())
    # KPackage's KWin/Aurorae structure requires decoration.svgz (gzipped).
    (root / "decoration.svgz").write_bytes(gzip.compress(decoration().encode(), mtime=0))
    for name, (c, kind) in BUTTONS.items():
        (root / f"{name}.svg").write_text(button(c, kind))
    print(f"wrote the {NAME} window decoration to {root}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
