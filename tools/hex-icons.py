#!/usr/bin/env python3
"""CybroidOS Hex's icon themes: the dock's apps as the design draws them, white
line icons on tiles, each tile its own shade: navy in CybroidOS-Hex, CIT blue
and slate in CybroidOS-Hex-Light. Everything else comes from WhiteSur-dark or
WhiteSur-light (Inherits).

    tools/hex-icons.py <package root>

Writes usr/share/icons/CybroidOS-Hex and CybroidOS-Hex-Light. The icons are our
own drawings (no other company's marks): a grid for Apps, a globe for the
web browser, a folder, a prompt, code brackets, a gear and a bin.
"""

import pathlib
import sys

# (shade top, shade bottom, the icon on a 24-unit grid)
GRID = "M5 5h4v4H5zM10 5h4v4h-4zM15 5h4v4h-4zM5 10h4v4H5zM10 10h4v4h-4zM15 10h4v4h-4zM5 15h4v4H5zM10 15h4v4h-4zM15 15h4v4h-4z"
GLOBE = "M12 3a9 9 0 1 0 0 18a9 9 0 1 0 0-18M3 12h18M12 3c3 3 3 15 0 18M12 3c-3 3-3 15 0 18"
FOLDER = "M3 7h7l2 2h9v10H3z"
PROMPT = "M5 8l4 4-4 4M12 16h7"
CODE = "M9 7l-5 5 5 5M15 7l5 5-5 5"
GEAR = "M12 9a3 3 0 1 0 0 6a3 3 0 1 0 0-6M12 2v3M12 19v3M2 12h3M19 12h3M4.9 4.9l2.1 2.1M17 17l2.1 2.1M4.9 19.1L7 17M17 7l2.1-2.1"
BIN = "M5 7h14M10 7V4h4v3M6 7l1 13h10l1-13"

ICONS = {  # name: (context, top, bottom, path)
    "cybroid-apps": ("apps", "#1a4cb0", "#123a8c", GRID),
    "firefox-esr": ("apps", "#173a7a", "#0f2a5c", GLOBE),
    "firefox": ("apps", "#173a7a", "#0f2a5c", GLOBE),
    "org.kde.dolphin": ("apps", "#155083", "#0e3a63", FOLDER),
    "system-file-manager": ("apps", "#155083", "#0e3a63", FOLDER),
    "utilities-terminal": ("apps", "#1c2746", "#141c33", PROMPT),
    "org.kde.konsole": ("apps", "#1c2746", "#141c33", PROMPT),
    "kwrite": ("apps", "#243872", "#1a2a55", CODE),
    "org.kde.kwrite": ("apps", "#243872", "#1a2a55", CODE),
    "accessories-text-editor": ("apps", "#243872", "#1a2a55", CODE),
    "preferences-system": ("apps", "#27365f", "#1d2848", GEAR),
    "systemsettings": ("apps", "#27365f", "#1d2848", GEAR),
    "user-trash": ("places", "#1c2746", "#141c33", BIN),
    "user-trash-full": ("places", "#1c2746", "#141c33", BIN + "M10 11v6M14 11v6"),
}


# Hex Light's tiles (the design's Hex // Light dock), by the dark tile's
# shade: each lit a little at the top.
LIGHT = {
    "#1a4cb0": "#1f5fe0", "#173a7a": "#2b4c8f", "#155083": "#0b8fc4", "#1c2746": "#1d2a4a",
    "#243872": "#3a5aa8", "#27365f": "#4a5b85",
}
TRASH_LIGHT = "#6b7a9c"


def lit(c, k=0.14):
    r, g, b = (int(c[i:i + 2], 16) for i in (1, 3, 5))
    return "#" + "".join(f"{round(v + (255 - v) * k):02x}" for v in (r, g, b))


def svg(top, bottom, path):
    # A 128 tile, 4 px of air round it (as the dock's other icons have), the
    # corners rounded at the design's 10 of 48; the icon 26 of 48 across.
    s = 120 * 26 / 48 / 24
    o = 64 - 12 * s
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">'
        f'<defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{top}"/>'
        f'<stop offset="1" stop-color="{bottom}"/></linearGradient></defs>'
        '<rect x="4" y="4" width="120" height="120" rx="25" fill="url(#g)"/>'
        '<path d="M29 4.5H99A24.5 24.5 0 0 1 120 16" fill="none" stroke="#ffffff" stroke-opacity=".12"/>'
        '<path d="M8 16A24.5 24.5 0 0 1 29 4.5" fill="none" stroke="#ffffff" stroke-opacity=".12"/>'
        f'<path transform="translate({o:.2f} {o:.2f}) scale({s:.4f})" d="{path}" fill="none" stroke="#e8eefc" '
        'stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/></svg>\n'
    )


def main(out):
    for theme, light, inherits in (("CybroidOS-Hex", False, "WhiteSur-dark,breeze-dark"), ("CybroidOS-Hex-Light", True, "WhiteSur-light,breeze")):
        root = pathlib.Path(out) / "usr/share/icons" / theme
        for name, (ctx, top, bottom, path) in ICONS.items():
            if light:
                bottom = TRASH_LIGHT if ctx == "places" else LIGHT[top]
                top = lit(bottom)
            f = root / ctx / "scalable" / f"{name}.svg"
            f.parent.mkdir(parents=True, exist_ok=True)
            f.write_text(svg(top, bottom, path))
        (root / "index.theme").write_text(
            "[Icon Theme]\n"
            f"Name={theme.replace('CybroidOS-', 'CybroidOS ').replace('-', ' ')}\n"
            "Comment=CybroidOS Hex: the dock's apps as tiles, the rest from WhiteSur\n"
            f"Inherits={inherits},hicolor\n"
            "Directories=apps/scalable,places/scalable\n\n"
            "[apps/scalable]\nContext=Applications\nSize=128\nMinSize=16\nMaxSize=512\nType=Scalable\n\n"
            "[places/scalable]\nContext=Places\nSize=128\nMinSize=16\nMaxSize=512\nType=Scalable\n"
        )
        print(f"wrote {len(ICONS)} icons to {root}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
