#!/usr/bin/env python3
"""Generates Hex's text editor colour themes (cybroid-plasma).

KDE's text editors (KWrite, Kate, and the editor in KDevelop and others)
draw their writing area from a KSyntaxHighlighting colour theme, not from
the colour scheme. With automatic selection they chose Breeze Dark's grey,
which sat apart from Hex's navy. These two themes, "CybroidOS Hex" and
"CybroidOS Hex Light", use Hex's colours (CybroidHex*.colors and the Kvantum
themes' selection, tools/kvantum-hex.py); cybroid-appearance chooses them in
Hex and goes back to automatic selection in Horizon.

    tools/editor-theme.py <package files root>
        # writes <root>/usr/share/org.kde.syntax-highlighting/themes/
"""

import json
import pathlib
import sys

THEMES = {
    "cybroid-hex": dict(
        name="CybroidOS Hex", bg="#060c1e", gutter="#080f24", line="#0b1a3a", ink="#e8eefc",
        soft="#8fa3c8", faint="#3a4a72", sel="#0c4f72", find="#5a4a10", accent="#1ccbff",
        keyword="#1ccbff", control="#7fdcff", func="#8fb4ff", type="#5ee6c8", string="#f6c177",
        number="#ff9e64", comment="#6b7ea6", preproc="#c79bff", builtin="#3a7cff", error="#ff5d6c",
        warn="#ffb547", ok="#3fd68f",
    ),
    "cybroid-hex-light": dict(
        name="CybroidOS Hex Light", bg="#ffffff", gutter="#f4f7fc", line="#eef3fc", ink="#0b1634",
        soft="#4a5b85", faint="#b8c4dc", sel="#cfdcf8", find="#ffe9a8", accent="#1f5fe0",
        keyword="#1f5fe0", control="#0b6fb0", func="#3a4fc0", type="#0a7f6a", string="#a3530c",
        number="#b43c00", comment="#6b7a9c", preproc="#7a3fc0", builtin="#1f5fe0", error="#c8102e",
        warn="#a86400", ok="#13804a",
    ),
}


def theme(c):
    def st(colour, **kw):
        return {"text-color": colour, "selected-text-color": colour, **kw}

    return {
        "metadata": {"name": c["name"], "revision": 1, "license": "MIT", "author": "CybroidOS"},
        "text-styles": {
            "Normal": st(c["ink"]),
            "Keyword": st(c["keyword"], bold=True),
            "Function": st(c["func"]),
            "Variable": st(c["ink"]),
            "ControlFlow": st(c["control"], bold=True),
            "Operator": st(c["soft"]),
            "BuiltIn": st(c["builtin"]),
            "Extension": st(c["func"]),
            "Preprocessor": st(c["preproc"]),
            "Attribute": st(c["type"]),
            "Char": st(c["string"]),
            "SpecialChar": st(c["number"]),
            "String": st(c["string"]),
            "VerbatimString": st(c["string"]),
            "SpecialString": st(c["number"]),
            "Import": st(c["preproc"]),
            "DataType": st(c["type"]),
            "DecVal": st(c["number"]),
            "BaseN": st(c["number"]),
            "Float": st(c["number"]),
            "Constant": st(c["number"]),
            "Comment": st(c["comment"], italic=True),
            "Documentation": st(c["comment"]),
            "Annotation": st(c["preproc"]),
            "CommentVar": st(c["accent"]),
            "RegionMarker": st(c["accent"], **{"background-color": c["line"]}),
            "Information": st(c["ok"]),
            "Warning": st(c["warn"]),
            "Alert": st(c["error"], bold=True),
            "Error": st(c["error"], underline=True),
            "Others": st(c["type"]),
        },
        "editor-colors": {
            "BackgroundColor": c["bg"],
            "BracketMatching": c["sel"],
            "CodeFolding": c["line"],
            "CurrentLine": c["line"],
            "CurrentLineNumber": c["accent"],
            "IconBorder": c["gutter"],
            "IndentationLine": c["faint"],
            "LineNumbers": c["soft"],
            "MarkBookmark": c["accent"],
            "MarkBreakpointActive": c["error"],
            "MarkBreakpointReached": c["warn"],
            "MarkBreakpointDisabled": c["faint"],
            "MarkExecution": c["ok"],
            "MarkWarning": c["warn"],
            "MarkError": c["error"],
            "ModifiedLines": c["warn"],
            "ReplaceHighlight": c["sel"],
            "SavedLines": c["ok"],
            "SearchHighlight": c["find"],
            "Separator": c["faint"],
            "SpellChecking": c["error"],
            "TabMarker": c["faint"],
            "TemplateBackground": c["gutter"],
            "TemplatePlaceholder": c["line"],
            "TemplateFocusedPlaceholder": c["sel"],
            "TemplateReadOnlyPlaceholder": c["gutter"],
            "TextSelection": c["sel"],
            "WordWrapMarker": c["faint"],
        },
    }


def main(root):
    d = pathlib.Path(root) / "usr/share/org.kde.syntax-highlighting/themes"
    d.mkdir(parents=True, exist_ok=True)
    for fname, c in THEMES.items():
        (d / f"{fname}.theme").write_text(json.dumps(theme(c), indent=2) + "\n")
    print(f"wrote {len(THEMES)} themes to {d}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
