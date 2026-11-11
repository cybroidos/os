#!/usr/bin/env python3
"""Patches Plank's source so a bottom dock floats above the screen's edge.

Plank always draws its strip flush with the edge. macOS's Dock (and Plasma's
floating panels) sit a few pixels above it. This adds PLANK_EDGE_GAP (pixels,
read from the environment at start, bottom docks only): the gap counts as
part of the dock's bottom padding, so the icons rise, the hidden dock still
wakes at the very edge and the space under the strip still belongs to the
dock, while the strip and the running-app dots are drawn above the gap.

    tools/plank-edge-gap.py <plank source dir>

Each edit must match exactly once, so a new Plank release that moved the
code fails the build instead of shipping a half-patched dock.
"""

import pathlib
import sys

EDITS = {
    "lib/PositionManager.vala": [
        # The gap, read once.
        (
            "\t\tint bottom_offset;\n",
            "\t\tint bottom_offset;\n"
            "\t\t// CIT-OS: pixels between a bottom dock and the screen's edge.\n"
            "\t\tpublic int EdgeGap { get; private set; default = 0; }\n",
        ),
        (
            "\t\t\tbottom_offset = theme.get_bottom_offset () + BottomPadding;\n",
            "\t\t\tbottom_offset = theme.get_bottom_offset () + BottomPadding;\n"
            "\t\t\tEdgeGap = (Position == Gtk.PositionType.BOTTOM) ? int.max (0, int.parse (Environment.get_variable (\"PLANK_EDGE_GAP\") ?? \"0\")) : 0;\n"
            "\t\t\tbottom_offset += EdgeGap;\n",
        ),
        # The strip is drawn without the gap...
        (
            "\t\t\tvar background_height = int.max (0, height);\n",
            "\t\t\tvar background_height = int.max (0, height - EdgeGap);\n",
        ),
        # ...and above it (two places: filled and centred docks).
        (
            "\t\t\t\t\tx += (width - DockBackgroundWidth) / 2;\n\t\t\t\t\ty += height - DockBackgroundHeight;\n",
            "\t\t\t\t\tx += (width - DockBackgroundWidth) / 2;\n\t\t\t\t\ty += height - DockBackgroundHeight - EdgeGap;\n",
        ),
        (
            "\t\t\t\tx = (int) Math.round (center_first.x - padding_first);\n\t\t\t\ty += height - DockBackgroundHeight;\n",
            "\t\t\t\tx = (int) Math.round (center_first.x - padding_first);\n\t\t\t\ty += height - DockBackgroundHeight - EdgeGap;\n",
        ),
    ],
    "lib/DockRenderer.vala": [
        # Running-app dots sit on the strip, not in the gap.
        (
            "\t\t\t\ty = item_buffer.Height - indicator_surface.Height / 2.0 - 2.0 * theme.get_bottom_offset () - indicator_surface.Height / 24.0;\n",
            "\t\t\t\ty = item_buffer.Height - indicator_surface.Height / 2.0 - 2.0 * theme.get_bottom_offset () - indicator_surface.Height / 24.0 - position_manager.EdgeGap;\n",
        ),
    ],
}


def main(src):
    root = pathlib.Path(src)
    for name, edits in EDITS.items():
        f = root / name
        text = f.read_text()
        for old, new in edits:
            n = text.count(old)
            if n != 1:
                sys.exit(f"{name}: expected one match, found {n}:\n{old}")
            text = text.replace(old, new)
        f.write_text(text)
        print(f"patched {name} ({len(edits)} edits)")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
