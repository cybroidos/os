#!/usr/bin/env python3
"""Generates CybroidOS's Kvantum themes (cybroid-plasma): how app controls look.

Kvantum is the Qt style engine that draws buttons, fields, sidebars, lists,
tabs and menus inside apps (Debian's qt-style-kvantum). These themes start
from WhiteSur's opaque Kvantum themes (GPL-3.0, Vince Liuice,
github.com/vinceliuice/WhiteSur-kde, release 2024-11-18): rounded, Mac-like
shapes. They are recoloured to CybroidOS: greys become navy-tinted greys of the
same lightness, Apple blues become the CybroidOS blue, and the base colours
(window, fields, text, selection, links) come from the CybroidOS Horizon and
Horizon Light colour schemes. No translucency or blur: CybroidOS surfaces are
solid.

    tools/kvantum-theme.py <WhiteSur-kde checkout> <out>
        # writes <out>/usr/share/Kvantum/CybroidOS{,Light}/
"""

import colorsys
import pathlib
import re
import sys

BLUE_HUE = 0.612  # #3a7cff, the CybroidOS blue

# Base colours from the colour schemes (CybroidHorizon*.colors).
DARK = {
    "window.color": "#111b3d", "inactive.window.color": "#111b3d",
    "base.color": "#0e1735", "inactive.base.color": "#0e1735",
    "alt.base.color": "#111b3c", "inactive.alt.base.color": "#101a3a",
    "button.color": "#26345f", "light.color": "#2c3b69", "mid.light.color": "#22305a",
    "dark.color": "#0a1128", "mid.color": "#1a2650",
    "highlight.color": "#3a7cff", "inactive.highlight.color": "#2f62c4",
    "text.color": "#e8eefc", "inactive.text.color": "#c4d0ea",
    "window.text.color": "#e8eefc", "inactive.window.text.color": "#c4d0ea",
    "button.text.color": "#e8eefc", "disabled.text.color": "#7f8fb3",
    "tooltip.base.color": "#121c40", "tooltip.text.color": "#e8eefc",
    "highlight.text.color": "#ffffff", "inactive.highlight.text.color": "#f0f4ff",
    "link.color": "#7fdcff", "link.visited.color": "#afa0ff",
    "progress.indicator.text.color": "#ffffff",
}
LIGHT = {
    "window.color": "#f2f4f8", "inactive.window.color": "#f2f4f8",
    "base.color": "#ffffff", "inactive.base.color": "#ffffff",
    "alt.base.color": "#f7f8fb", "inactive.alt.base.color": "#f7f8fb",
    "button.color": "#ffffff", "light.color": "#ffffff", "mid.light.color": "#f0f2f7",
    "dark.color": "#b8c0d2", "mid.color": "#d6dbe6",
    "highlight.color": "#3a7cff", "inactive.highlight.color": "#9db8f0",
    "text.color": "#161e34", "inactive.text.color": "#3a4460",
    "window.text.color": "#161e34", "inactive.window.text.color": "#3a4460",
    "button.text.color": "#161e34", "disabled.text.color": "#8a93a8",
    "tooltip.base.color": "#fafbfd", "tooltip.text.color": "#161e34",
    "highlight.text.color": "#ffffff", "inactive.highlight.text.color": "#ffffff",
    "link.color": "#1f5fe0", "link.visited.color": "#6e50c8",
    "progress.indicator.text.color": "#ffffff",
}

HEX = re.compile(r"#([0-9a-fA-F]{6})\b")


def recolour(dark):
    def fn(m):
        v = m.group(1)
        r, g, b = (int(v[i : i + 2], 16) / 255 for i in (0, 2, 4))
        h, l, s = colorsys.rgb_to_hls(r, g, b)
        chroma = max(r, g, b) - min(r, g, b)
        if l <= 0.0 or l >= 1.0:
            return m.group(0)  # black (shadows, masks) and white (highlights)
        if chroma < 0.08:
            # A grey: the same lightness, tinted navy (more in the dark).
            if dark:
                ns = 0.55 * (1 - l) + 0.22 * l
                nl = l * 1.02
            else:
                ns = 0.32 if l > 0.6 else 0.25
                nl = l
            r2, g2, b2 = colorsys.hls_to_rgb(BLUE_HUE, min(nl, 0.985), ns)
        elif 0.53 <= h <= 0.72 and s > 0.35:
            # Apple's blues: the CybroidOS blue at the same lightness.
            r2, g2, b2 = colorsys.hls_to_rgb(BLUE_HUE, l, max(s, 0.85))
        else:
            return m.group(0)
        return "#%02x%02x%02x" % (round(r2 * 255), round(g2 * 255), round(b2 * 255))

    return fn


def kvconfig(text, colours, name):
    def colours_section(m):
        lines = [f"{k}={v}" for k, v in colours.items()]
        return "[GeneralColors]\n" + "\n".join(lines) + "\n\n"

    text = re.sub(r"\[GeneralColors\]\n(?:[^\[]*\n)*?\n(?=\[)", colours_section, text, count=1)
    # Solid surfaces, no blur (and so nothing to fall back from on VMs).
    for key, val in (("translucent_windows", "false"), ("blurring", "false"), ("popup_blurring", "false"), ("reduce_window_opacity", "0"), ("reduce_menu_opacity", "0")):
        text = re.sub(rf"^{key}=.*$", f"{key}={val}", text, flags=re.M)
    head = (
        f"# {name}: CybroidOS's Kvantum theme (cybroid-plasma), made by tools/kvantum-theme.py\n"
        "# from WhiteSur's opaque Kvantum theme (GPL-3.0, Vince Liuice), recoloured.\n"
    )
    return head + text


def main(src, out):
    src = pathlib.Path(src) / "Kvantum/WhiteSur-opaque"
    for name, base, dark, colours in (
        ("CybroidOS", "WhiteSur-opaqueDark", True, DARK),
        ("CybroidOSLight", "WhiteSur-opaque", False, LIGHT),
    ):
        d = pathlib.Path(out) / "usr/share/Kvantum" / name
        d.mkdir(parents=True, exist_ok=True)
        svg = HEX.sub(recolour(dark), (src / f"{base}.svg").read_text())
        (d / f"{name}.svg").write_text(svg)
        (d / f"{name}.kvconfig").write_text(kvconfig((src / f"{base}.kvconfig").read_text(), colours, name))
        print(f"wrote {d}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
