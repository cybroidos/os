#!/usr/bin/env python3
"""Generates Hex's Kvantum themes (cybroid-plasma): how app controls look in Hex.

Horizon's app controls are CybroidOS's Kvantum themes (tools/kvantum-theme.py,
rounded). Hex is the HUD design: square panels with cut corners, thin cyan
edges, no shadows. These themes are made from Horizon's, already in the
package tree: their arrows and small signs are kept (recoloured to Hex's
accent), and every frame and fill (buttons, fields, tabs, menus, lists,
tooltips, progress bars, sliders, scroll bars) and every check box, radio
button and slider handle is drawn here instead, from geometry:

  * a frame piece is drawn at the size the theme's frame takes on screen (one
    SVG unit to one pixel), so the 1 px edges stay crisp;
  * the edges are filled polygons, never strokes (a stroke at a piece's edge
    widens its bounds by half a pixel and leaves a seam);
  * cut corners are 45 degree chamfers, top left and bottom right (Hangar's
    HUD frames), smaller than the frame so they stay inside the piece.

Colours come from Hex's colour schemes (CybroidHex*.colors). Radio buttons
and slider handles are hexagons.

    tools/kvantum-hex.py <package files root>
        # reads  <root>/usr/share/Kvantum/CybroidOS{,Light}/ (the drawings of
        #        both; the settings of CybroidOS for both)
        # writes <root>/usr/share/Kvantum/CybroidHex{,Light}/
"""

import colorsys
import math
import pathlib
import re
import sys

R2 = math.sqrt(2)

DARK = {
    "ink": "#e8eefc", "soft": "#8fa3c8", "window": "#080f24", "view": "#060c1e",
    "button": "#0e1834", "header": "#0a132c", "tooltip": "#080f24",
    "accent": "#1ccbff", "on_accent": "#04102a", "line": "#1ccbff", "line_a": 0.30,
    "hover_a": 0.10, "shade": "#8fa3c8",
    # Selections (list items, selected text): the accent mixed into the
    # ground, solid, with the usual text on it. Translucent selections drew
    # apps' "selected text" colour (dark) on a dark ground.
    "select": "#0c4f72", "on_select": "#ffffff",
}
LIGHT = {
    "ink": "#0b1634", "soft": "#4a5b85", "window": "#e9eff9", "view": "#ffffff",
    "button": "#f6f9ff", "header": "#fafcff", "tooltip": "#ffffff",
    "accent": "#1f5fe0", "on_accent": "#ffffff", "line": "#1f5fe0", "line_a": 0.32,
    "hover_a": 0.08, "shade": "#4a5b85",
    "select": "#cfdcf8", "on_select": "#0b1634",
}

STATES = ("normal", "focused", "pressed", "toggled", "disabled")

# Each frame element: its look ("kind"), which corners are cut, and how big
# the cut is (at most the frame's size).
ELEMENTS = {
    "button": ("control", "tl br", 4),
    "combo": ("control", "tl br", 4),
    "tbutton": ("flat", "tl br", 4),
    "lineedit": ("field", "br", 4),
    "tlineedit": ("field", "br", 4),
    "spinbox": ("field", "br", 4),
    "tab": ("tab", "tl", 4),
    "tframe": ("panel", "br", 5),
    "group": ("panel", "tl br", 5),
    "common": ("line", "", 0),
    "dock": ("line", "", 0),
    "header": ("header", "", 0),
    "toolbar": ("none", "", 0),
    "slider": ("groove", "", 0),
    "progress": ("groove", "", 0),
    "progress-pattern": ("fill", "", 0),
    "itemview": ("select", "tl br", 3),
    "scrollbarslider": ("handle", "", 0),
    "menubaritem": ("select", "", 0),
    "menu": ("popup", "tl br", 6),
    "menuitem": ("select", "", 0),
    "tooltip": ("popup", "tl br", 4),
    "focus": ("focus", "tl br", 3),
}
# The frame size each element is drawn for, written to every section that
# uses it (Kvantum stretches pieces to the frame: the same size keeps 1 px
# edges at 1 px).
FRAME = {
    "button": 4, "combo": 4, "tbutton": 4, "lineedit": 4, "tlineedit": 4,
    "spinbox": 4, "tab": 4, "tframe": 5, "group": 5, "common": 1, "dock": 1,
    "header": 1, "toolbar": 1, "slider": 2, "progress": 2, "progress-pattern": 2,
    "itemview": 3, "scrollbarslider": 2, "menubaritem": 2, "menu": 6,
    "menuitem": 3, "tooltip": 4, "focus": 3,
}
INDICATORS = (
    "checkbox", "checkbox-checked", "checkbox-tristate", "radio", "radio-checked",
    "slidercursor", "slidercursor-tickless", "menu-checkbox", "menu-checkbox-checked",
    "menu-radio", "menu-radio-checked", "item-checkbox", "item-checkbox-checked",
    "item-checkbox-tristate",
)


def look(kind, state, p):
    """(fill, fill opacity, edge, edge opacity) for a kind of element in a state."""
    a, line, la = p["accent"], p["line"], p["line_a"]
    off = state == "disabled"
    if kind == "control":
        if state == "focused":
            return p["button"], 1, a, 0.9
        if state in ("pressed", "toggled"):
            return a, 0.24, a, 1
        return p["button"], 0.6 if off else 1, line, la * (0.4 if off else 1)
    if kind == "flat":
        if state == "focused":
            return a, p["hover_a"], a, 0.6
        if state in ("pressed", "toggled"):
            return a, 0.22, a, 0.9
        return None, 0, None, 0
    if kind == "field":
        if state in ("focused", "pressed", "toggled"):
            return p["view"], 1, a, 1
        return p["view"], 0.6 if off else 1, line, la * (0.5 if off else 1.2)
    if kind == "tab":
        if state == "toggled":
            return p["window"], 1, a, 0.9
        if state in ("focused", "pressed"):
            return a, p["hover_a"], line, la
        return None, 0, None, 0
    if kind == "panel":
        return p["window"], 1, line, la
    if kind == "line":
        return None, 0, line, la
    if kind == "header":
        return p["header"], 1, line, la * 0.7
    if kind == "groove":
        if state == "toggled":
            return a, 1, None, 0
        return p["shade"], 0.18, None, 0
    if kind == "fill":
        return a, 0.45 if off else 1, None, 0
    if kind == "select":
        if state == "focused":
            return a, p["hover_a"], None, 0
        if state in ("pressed", "toggled"):
            return p["select"], 1, a, 0.8
        return None, 0, None, 0
    if kind == "handle":
        if state == "focused":
            return p["soft"], 0.75, None, 0
        if state in ("pressed", "toggled"):
            return a, 1, None, 0
        return p["soft"], 0.4, None, 0
    if kind == "popup":
        return p["window"], 1, a, 0.5
    if kind == "focus":
        return None, 0, a, 0.9
    return None, 0, None, 0  # none


def fmt(v):
    return f"{v:.3f}".rstrip("0").rstrip(".")


def poly(points, colour, opacity):
    if not colour or opacity <= 0:
        return ""
    pts = " ".join(f"{fmt(x)},{fmt(y)}" for x, y in points)
    return f'<polygon points="{pts}" fill="{colour}" fill-opacity="{fmt(opacity)}"/>'


def corner(f, c):
    """The top left corner piece (f by f) as (edge polygon, fill polygon).
    The edge is 1 wide; with c > 0 the corner is cut at 45 degrees."""
    if c <= 0:
        edge = [(0, 0), (f, 0), (f, 1), (1, 1), (1, f), (0, f)]
        fill = [(1, 1), (f, 1), (f, f), (1, f)]
    else:
        k = c + R2 - 1  # where the inner line meets y = 1 and x = 1
        edge = [(0, c), (c, 0), (f, 0), (f, 1), (k, 1), (1, k), (1, f), (0, f)]
        fill = [(1, k), (k, 1), (f, 1), (f, f), (1, f)]
    return edge, fill


def frame_element(name, kind, cuts, cut, f, p, ox, oy):
    """Kvantum's nine pieces for one element in each state, side by side."""
    out = []
    L = 8  # the length of edge and interior pieces (they are stretched)
    c = min(cut, f - 1) if f > 1 else 0
    for si, state in enumerate(STATES):
        fill, fa, edge, ea = look(kind, state, p)
        if not edge:
            edge, ea = fill, fa  # no edge: the fill reaches the outside
        x0, y0 = ox + si * (2 * f + L + 8), oy
        g = []

        def piece(pid, w, h, x, y, shapes):
            body = "".join(shapes)
            g.append(
                f'<g id="{pid}" transform="translate({fmt(x)},{fmt(y)})">'
                f'<rect width="{fmt(w)}" height="{fmt(h)}" fill="#000000" fill-opacity="0"/>{body}</g>'
            )

        def mirrored(points, mx, my):
            return [((f - x) if mx else x, (f - y) if my else y) for x, y in points]

        for part, mx, my in (("topleft", 0, 0), ("topright", 1, 0), ("bottomleft", 0, 1), ("bottomright", 1, 1)):
            short = {"topleft": "tl", "topright": "tr", "bottomleft": "bl", "bottomright": "br"}[part]
            e, fl = corner(f, c if short in cuts.split() else 0)
            if f == 1:  # a hairline frame: the corner is all edge
                e, fl = [(0, 0), (1, 0), (1, 1), (0, 1)], []
            px = x0 + (f + L if mx else 0)
            py = y0 + (f + L if my else 0)
            piece(f"{name}-{state}-{part}", f, f, px, py,
                  [poly(mirrored(e, mx, my), edge, ea), poly(mirrored(fl, mx, my), fill, fa) if fl else ""])
        # Edges: a 1 wide line on the outside, the fill inside.
        piece(f"{name}-{state}-top", L, f, x0 + f, y0,
              [poly([(0, 0), (L, 0), (L, 1), (0, 1)], edge, ea), poly([(0, 1), (L, 1), (L, f), (0, f)], fill, fa) if f > 1 else ""])
        piece(f"{name}-{state}-bottom", L, f, x0 + f, y0 + f + L,
              [poly([(0, f - 1), (L, f - 1), (L, f), (0, f)], edge, ea), poly([(0, 0), (L, 0), (L, f - 1), (0, f - 1)], fill, fa) if f > 1 else ""])
        piece(f"{name}-{state}-left", f, L, x0, y0 + f,
              [poly([(0, 0), (1, 0), (1, L), (0, L)], edge, ea), poly([(1, 0), (f, 0), (f, L), (1, L)], fill, fa) if f > 1 else ""])
        piece(f"{name}-{state}-right", f, L, x0 + f + L, y0 + f,
              [poly([(f - 1, 0), (f, 0), (f, L), (f - 1, L)], edge, ea), poly([(0, 0), (f - 1, 0), (f - 1, L), (0, L)], fill, fa) if f > 1 else ""])
        piece(f"{name}-{state}", L, L, x0 + f, y0 + f, [poly([(0, 0), (L, 0), (L, L), (0, L)], fill, fa)])
        out.extend(g)
    return out


def hexagon(cx, cy, r):
    return [(cx + r * math.cos(math.radians(60 * i)), cy + r * math.sin(math.radians(60 * i))) for i in range(6)]


def ring(outer, inner):
    """A polygon outline as one path (even-odd): outer minus inner."""
    d = "M" + " L".join(f"{fmt(x)},{fmt(y)}" for x, y in outer) + " Z "
    d += "M" + " L".join(f"{fmt(x)},{fmt(y)}" for x, y in reversed(inner)) + " Z"
    return d


def indicator(name, state, p, x, y):
    """A 16 by 16 sign: square check boxes with a cut corner, hexagon radios
    and slider handles."""
    a, ink, line = p["accent"], p["ink"], p["line"]
    off = state == "disabled"
    hot = state in ("focused", "pressed")
    S = 16
    body = []
    base = name.replace("menu-", "").replace("item-", "")

    def path(d, colour, op):
        body.append(f'<path d="{d}" fill="{colour}" fill-opacity="{fmt(op)}" fill-rule="evenodd"/>')

    if base.startswith("checkbox"):
        # A 13 px box, cut at the top left, 1.5 inside the sign.
        o = [(1.5 + 3, 1.5), (14.5, 1.5), (14.5, 14.5), (1.5, 14.5), (1.5, 1.5 + 3)]
        i = [(2.5 + 3 - 1 + R2 / 2, 2.5), (13.5, 2.5), (13.5, 13.5), (2.5, 13.5), (2.5, 2.5 + 3 - 1 + R2 / 2)]
        on = base != "checkbox"
        if on:
            path("M" + " L".join(f"{fmt(px)},{fmt(py)}" for px, py in o) + " Z", a, 0.45 if off else 1)
            if base == "checkbox-checked":
                path("M4.6,8.2 L6.9,10.5 L11.6,5.3 L12.8,6.4 L6.9,12.8 L3.4,9.3 Z", p["on_accent"], 1)
            else:
                path("M4.5,7.2 H11.5 V8.8 H4.5 Z", p["on_accent"], 1)
        else:
            if hot:
                path("M" + " L".join(f"{fmt(px)},{fmt(py)}" for px, py in i) + " Z", a, p["hover_a"])
            path(ring(o, i), a if hot else line, 1 if hot else (0.25 if off else 0.7))
    elif base.startswith("radio"):
        outer, inner = hexagon(8, 8, 6.8), hexagon(8, 8, 5.6)
        if hot:
            path("M" + " L".join(f"{fmt(px)},{fmt(py)}" for px, py in inner) + " Z", a, p["hover_a"])
        on = base == "radio-checked"
        path(ring(outer, inner), a if (hot or on) else line, (0.45 if off else 1) if (hot or on) else (0.25 if off else 0.7))
        if on:
            path("M" + " L".join(f"{fmt(px)},{fmt(py)}" for px, py in hexagon(8, 8, 3.4)) + " Z", a, 0.45 if off else 1)
    else:  # slider handle: a hexagon, filled, with an accent edge
        outer, inner = hexagon(8, 8, 7), hexagon(8, 8, 5.8)
        path("M" + " L".join(f"{fmt(px)},{fmt(py)}" for px, py in inner) + " Z", p["button"], 1)
        path(ring(outer, inner), a, 0.45 if off else 1)
        path("M" + " L".join(f"{fmt(px)},{fmt(py)}" for px, py in hexagon(8, 8, 2.2)) + " Z", a, 0.45 if off else (1 if hot else 0.7))
    return (
        f'<g id="{name}-{state}" transform="translate({fmt(x)},{fmt(y)})">'
        f'<rect width="{S}" height="{S}" fill="#000000" fill-opacity="0"/>{"".join(body)}</g>'
    )


HEXCOL = re.compile(r"#([0-9a-fA-F]{6})\b")


def recolour(accent):
    """Horizon's blues become Hex's accent at the same lightness."""
    ar, ag, ab = (int(accent[i : i + 2], 16) / 255 for i in (1, 3, 5))
    ah, _, as_ = colorsys.rgb_to_hls(ar, ag, ab)

    def fn(m):
        v = m.group(1)
        r, g, b = (int(v[i : i + 2], 16) / 255 for i in (0, 2, 4))
        h, l, s = colorsys.rgb_to_hls(r, g, b)
        if 0.57 <= h <= 0.66 and s > 0.5 and 0.25 < l < 0.85:
            r2, g2, b2 = colorsys.hls_to_rgb(ah, l, max(s, as_))
            return "#%02x%02x%02x" % (round(r2 * 255), round(g2 * 255), round(b2 * 255))
        return m.group(0)

    return fn


def replaced(element_id):
    """Is this id one of those drawn here (any state, piece or variant)?"""
    i = element_id[len("expand-"):] if element_id.startswith("expand-") else element_id
    for name in sorted(list(ELEMENTS) + list(INDICATORS), key=len, reverse=True):
        if i == name or i.startswith(name + "-"):
            rest = i[len(name) + 1:]
            first = rest.split("-")[0]
            if first in STATES or first in ("default", "inactive") or i == name:
                return True
    return False


def svg(src_text, p):
    # Retire the ids drawn here (renamed, so nothing is found twice).
    def rename(m):
        return f'id="retired-{m.group(1)}"' if replaced(m.group(1)) else m.group(0)

    text = re.sub(r'id="([^"]+)"', rename, src_text)
    text = HEXCOL.sub(recolour(p["accent"]), text)
    parts = ['<g id="cybroid-hex" transform="translate(2000,0)">']
    y = 0
    for name, (kind, cuts, cut) in ELEMENTS.items():
        f = FRAME[name]
        parts.extend(frame_element(name, kind, cuts, cut, f, p, 0, y))
        y += 2 * f + 8 + 8
    x = 0
    for name in INDICATORS:
        for si, state in enumerate(STATES):
            parts.append(indicator(name, state, p, x + si * 20, y))
        y += 20
    parts.append("</g>")
    return text.replace("</svg>", "\n".join(parts) + "\n</svg>")


def sections(text):
    """[(name, [lines])] in order, the header (before any section) as ''."""
    out, name, lines = [], "", []
    for line in text.splitlines():
        m = re.match(r"^\[(.+)\]$", line)
        if m:
            out.append((name, lines))
            name, lines = m.group(1), []
        else:
            lines.append(line)
    out.append((name, lines))
    return out


def kvconfig(text, p, name, dark):
    secs = sections(text)
    keys = {n: dict(l.split("=", 1) for l in ls if "=" in l and not l.startswith("#")) for n, ls in secs}

    def resolved(sec, key, depth=0):
        k = keys.get(sec, {})
        if key in k:
            return k[key]
        parent = k.get("inherits")
        return resolved(parent, key, depth + 1) if parent and depth < 8 else None

    colours = {
        "window.color": p["window"], "inactive.window.color": p["window"],
        "base.color": p["view"], "inactive.base.color": p["view"],
        "alt.base.color": p["header"], "inactive.alt.base.color": p["header"],
        "button.color": p["button"], "light.color": p["button"], "mid.light.color": p["header"],
        "dark.color": p["window"], "mid.color": p["header"],
        "highlight.color": p["select"], "inactive.highlight.color": p["select"],
        "text.color": p["ink"], "inactive.text.color": p["ink"],
        "window.text.color": p["ink"], "inactive.window.text.color": p["ink"],
        "button.text.color": p["ink"], "disabled.text.color": p["soft"],
        "tooltip.base.color": p["tooltip"], "tooltip.text.color": p["ink"],
        "highlight.text.color": p["on_select"], "inactive.highlight.text.color": p["on_select"],
        "link.color": p["accent"], "link.visited.color": p["soft"],
        "progress.indicator.text.color": p["ink"],
    }
    general = {
        "author": "CybroidOS", "comment": "Hex: CybroidOS's HUD design (made by tools/kvantum-hex.py)",
        "menu_shadow_depth": "0", "tooltip_shadow_depth": "0", "shadowless_popup": "true",
        "translucent_windows": "false", "blurring": "false", "popup_blurring": "false",
        "reduce_window_opacity": "0", "reduce_menu_opacity": "0", "slider_width": "4",
        "progressbar_thickness": "4", "dark_titlebar": "true" if dark else "false",
        "no_window_pattern": "true",
    }
    out = [
        f"# {name}: Hex's Kvantum theme (cybroid-plasma), made by tools/kvantum-hex.py from",
        "# CybroidOS's own (itself from WhiteSur's opaque Kvantum theme, GPL-3.0, Vince Liuice).",
    ]
    for sec, lines in secs:
        if sec:
            out.append(f"[{sec}]")
        if sec == "GeneralColors":
            out.extend(f"{k}={v}" for k, v in colours.items())
            out.append("")
            continue
        own = keys.get(sec, {})
        el = resolved(sec, "frame.element") if sec else None
        new = []
        for line in lines:
            if "=" in line and not line.startswith("#"):
                k, v = line.split("=", 1)
                if sec == "%General" and k in general:
                    v = general.pop(k)
                elif re.fullmatch(r"text\.(normal|focus|press|toggle)(\.inactive)?\.color", k):
                    v = p["ink"]
                elif k == "frame.expansion":
                    v = "0"
                elif k.startswith("frame.") and k[6:] in ("top", "bottom", "left", "right") and el in FRAME:
                    continue  # written below, the same on all four sides
                elif sec in ("Window", "Dialog") and k in ("interior", "frame"):
                    v = "false"
                line = f"{k}={v}"
            new.append(line)
        if sec == "%General":
            new[-1:-1] = [f"{k}={v}" for k, v in general.items()]
        if el in FRAME and (any(k.startswith("frame.") for k in own) or "frame.element" in own):
            f = FRAME[el]
            at = len(new) - 1 if new and new[-1] == "" else len(new)
            new[at:at] = [f"frame.top={f}", f"frame.bottom={f}", f"frame.left={f}", f"frame.right={f}"]
        out.extend(new)
    return "\n".join(out).rstrip("\n") + "\n"


def main(root):
    base = pathlib.Path(root) / "usr/share/Kvantum"
    for name, src, p, dark in (
        ("CybroidHex", "CybroidOS", DARK, True),
        ("CybroidHexLight", "CybroidOSLight", LIGHT, False),
    ):
        d = base / name
        d.mkdir(parents=True, exist_ok=True)
        (d / f"{name}.svg").write_text(svg((base / src / f"{src}.svg").read_text(), p))
        # Both from the dark theme's settings: the light one draws tabs as
        # buttons and puts a pill behind the toolbar combo's arrow.
        (d / f"{name}.kvconfig").write_text(kvconfig((base / "CybroidOS/CybroidOS.kvconfig").read_text(), p, name, dark))
        print(f"wrote {d}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
