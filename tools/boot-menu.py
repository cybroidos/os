#!/usr/bin/env python3
"""The CIT-OS boot menus of the live and installer ISO, in place of
live-build's stock Debian ones: GRUB (UEFI) and syslinux (BIOS).

    tools/boot-menu.py <dir with the ISO's boot/grub and isolinux folders>

Draws the background pictures (deep navy, the CIT mark, the name, a hairline
with a small hexagon: Hex's language) and writes GRUB's theme and syslinux's
menu colours over the ones there. The menu entries and kernel options are
left to tools/iso-brand.sh.
"""

import pathlib
import subprocess
import sys
import tempfile

NAVY_IN, NAVY_MID, NAVY_OUT = "#0d1c44", "#071027", "#030713"
ACC, BLUE, INK, MUTED, LINE = "#1ccbff", "#3a7cff", "#e8eefc", "#8fa3c8", "#1d3266"

# The CIT mark (784 units): bands in its gradient, traces and nodes in cyan.
MARK = (
    '<linearGradient id="mk" gradientUnits="userSpaceOnUse" x1="170" y1="640" x2="640" y2="110">'
    '<stop offset="0" stop-color="#3A7CFF"/><stop offset=".55" stop-color="#2C9DFF"/>'
    '<stop offset="1" stop-color="#1CCBFF"/></linearGradient>',
    '<g fill="none">'
    '<path d="M447.8 151.7 A228 228 0 0 0 253.3 533.5" stroke="url(#mk)" stroke-width="85"/>'
    '<path d="M264.5 544.7 A228 228 0 0 0 584.0 536.4" stroke="url(#mk)" stroke-width="85"/>'
    '<path d="M463.5 154.2 A228 228 0 0 1 589.4 225.4" stroke="url(#mk)" stroke-width="85"/>'
    '<g stroke="#18d8ff" stroke-width="8" stroke-linecap="round"><path d="M215.9 151.3 A305 305 0 0 1 624.1 151.3"/>'
    '<path d="M167.1 207.4 A305 305 0 0 0 115.2 367.4"/><path d="M120.6 436.2 A305 305 0 0 0 377.6 680.0"/>'
    '<path d="M446.6 681.8 A305 305 0 0 0 628.0 601.1"/><path d="M368.0 235.2 A152 152 0 0 0 363.1 518.9"/></g>'
    '<g fill="#18d8ff">'
    + "".join(
        f'<circle cx="{x}" cy="{y}" r="16"/>'
        for x, y in ((215.9, 151.3), (624.1, 151.3), (167.1, 207.4), (120.6, 436.2), (377.6, 680), (446.6, 681.8),
                     (628, 601.1), (368, 235.2), (363.1, 518.9))
    )
    + "</g></g>",
)


def background(w, h, mark_y, mark_size, word_y, word_size, rule_y):
    """A boot picture: navy, a faint grid, the mark centred by eye (as on the
    Hex wallpaper), the name in wide capitals, a hairline with a hexagon."""
    cx = w / 2
    s = mark_size / 784
    hexagon = " ".join(f"{cx + 5 * c:.1f},{rule_y + 5 * k:.1f}" for c, k in
                       ((0, -1), (0.866, -0.5), (0.866, 0.5), (0, 1), (-0.866, 0.5), (-0.866, -0.5)))
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}"><defs>'
        f'<radialGradient id="bg" gradientUnits="userSpaceOnUse" cx="{cx}" cy="{h * 0.36}" r="{w * 0.7}">'
        f'<stop offset="0" stop-color="{NAVY_IN}"/><stop offset=".55" stop-color="{NAVY_MID}"/>'
        f'<stop offset="1" stop-color="{NAVY_OUT}"/></radialGradient>'
        '<pattern id="grid" width="24" height="24" patternUnits="userSpaceOnUse">'
        f'<path d="M24 0H0V24" fill="none" stroke="{ACC}" stroke-opacity=".035"/></pattern>'
        f"{MARK[0]}</defs>"
        f'<rect width="{w}" height="{h}" fill="url(#bg)"/><rect width="{w}" height="{h}" fill="url(#grid)"/>'
        f'<g transform="translate({cx - 397 * s:.1f} {mark_y - 380 * s:.1f}) scale({s:.4f})">{MARK[1]}</g>'
        f'<text x="{cx}" y="{word_y}" text-anchor="middle" font-family="DejaVu Sans, sans-serif" font-weight="bold" '
        f'font-size="{word_size}" letter-spacing="{word_size * 0.32:.1f}" fill="{INK}">CIT-OS</text>'
        f'<path d="M{cx - 120} {rule_y} H{cx - 14} M{cx + 14} {rule_y} H{cx + 120}" stroke="{LINE}" stroke-width="1.5"/>'
        f'<polygon points="{hexagon}" fill="{ACC}"/>'
        "</svg>"
    )


def png(svg, out):
    with tempfile.NamedTemporaryFile("w", suffix=".svg", delete=False) as f:
        f.write(svg)
    subprocess.run(["rsvg-convert", "-o", str(out), f.name], check=True)
    pathlib.Path(f.name).unlink()


def solid(out, w, h, colour, alpha):
    png(f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}"><rect width="{w}" height="{h}" '
        f'fill="{colour}" fill-opacity="{alpha}"/></svg>', out)


# GRUB (UEFI): 800 x 600, the theme in live-theme/.
GRUB_THEME = f"""# CIT-OS boot menu (tools/boot-menu.py): deep navy, the mark, the entries
# under it with the chosen one lit from its left edge (Hex's lists).
desktop-image: "../splash.png"
title-text: ""
message-font: "Unifont Regular 16"
message-color: "{MUTED}"
terminal-font: "Unifont Regular 16"

+ boot_menu {{
        left = 30%
        width = 40%
        top = 54%
        height = 30%
        item_font = "Unifont Regular 16"
        item_color = "{MUTED}"
        selected_item_font = "Unifont Regular 16"
        selected_item_color = "#ffffff"
        selected_item_pixmap_style = "select_*.png"
        item_height = 28
        item_padding = 14
        item_spacing = 6
        icon_width = 0
        icon_height = 0
        item_icon_space = 0
        scrollbar = false
}}

# The countdown: GRUB fills in its text only on a progress bar, so this is
# one drawn as text alone (its bar in the background's colour).
+ progress_bar {{
        id = "__timeout__"
        top = 100%-60
        left = 20%
        width = 60%
        height = 20
        font = "Unifont Regular 16"
        text_color = "{MUTED}"
        fg_color = "{NAVY_OUT}"
        bg_color = "{NAVY_OUT}"
        border_color = "{NAVY_OUT}"
        text = "@TIMEOUT_NOTIFICATION_SHORT@"
}}

+ label {{
        top = 100%-32
        left = 0
        width = 100%
        height = 20
        align = "center"
        font = "Unifont Regular 16"
        color = "#4a5b85"
        text = "Enter to start    e to edit the options    c for a command line"
}}
"""

# syslinux (BIOS): 640 x 480; the menu in rows of 16 px under the name.
SYSLINUX_STD = f"""menu clear
menu background splash.png
menu color screen	* #00000000 #00000000 none
menu color title	* #00000000 #00000000 none
menu color border	* #00000000 #00000000 none
menu color unsel	* #ff8fa3c8 #00000000 none
menu color sel		* #ffffffff #661ccbff none
menu color hotkey	* #ff1ccbff #00000000 none
menu color hotsel	* #ffffffff #661ccbff none
menu color disabled	* #ff4a5b85 #00000000 none
menu color tabmsg	* #ff4a5b85 #00000000 none
menu color cmdmark	* #ff1ccbff #00000000 none
menu color cmdline	* #ffe8eefc #00000000 none
menu color timeout_msg	* #ff8fa3c8 #00000000 none
menu color timeout	* #ffffffff #00000000 none
menu color help		* #ff8fa3c8 #00000000 none
menu width 44
menu margin 10
menu vshift 16
menu rows 6
menu helpmsgrow 24
menu cmdlinerow 24
menu timeoutrow 26
menu tabmsgrow 28
menu tabmsg Enter to start, Tab to edit the options
"""


def main(root):
    root = pathlib.Path(root)
    grub, lin = root / "grub", root / "isolinux"
    # GRUB: 800 x 600 (config.cfg sets that mode); the menu starts at 54 %.
    png(background(800, 600, mark_y=168, mark_size=170, word_y=292, word_size=26, rule_y=314), grub / "splash.png")
    (grub / "live-theme").mkdir(parents=True, exist_ok=True)
    (grub / "live-theme" / "theme.txt").write_text(GRUB_THEME)
    # The chosen entry: a cyan wash with a lit left edge (Hex's selected row).
    solid(grub / "live-theme" / "select_c.png", 8, 8, ACC, 0.16)
    solid(grub / "live-theme" / "select_w.png", 3, 8, ACC, 1.0)
    for side in ("n", "s", "e", "nw", "ne", "sw", "se"):
        (grub / "live-theme" / f"select_{side}.png").unlink(missing_ok=True)
    # syslinux: 640 x 480; the menu's first row is row 16 (256 px).
    png(background(640, 480, mark_y=118, mark_size=128, word_y=212, word_size=21, rule_y=230), lin / "splash.png")
    (lin / "stdmenu.cfg").write_text(SYSLINUX_STD)
    print(f"wrote the CIT-OS boot menus in {root}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
