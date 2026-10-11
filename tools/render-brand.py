#!/usr/bin/env python3
"""Render CIT-OS identity files from common/branding/brand.toml.

Emits into an overlay directory that pi-gen copies into the image:

  usr/lib/os-release            OS identity
  etc/motd, etc/issue           login banner
  usr/share/citos/kiosk/        the kiosk web app (cage + Chromium)
  usr/share/plymouth/themes/citos/  the boot splash theme

Branding is defined once (brand.toml) and flows to the Pi stage (and later the
shared <brand>-base package). Logo/wallpaper images are copied in by the caller
(see targets/rpi/build.sh); this script only writes the text files.
"""

import argparse
import pathlib
import tomllib

BANNER = "\n".join(
    [
        "   ______ _____ _______        ____  _____",
        "  / ____/  _/__  __/  _/___    / __ \\/ ___/",
        " / /    / /   / /  / /  __ \\  / / / /\\__ \\",
        "/ /____/ /   / / _/ /  ___/ / /_/ /___/ /",
        "\\____/___/  /_/ /___/\\___/  \\____//____/",
    ]
)


def hex_to_rgb(value: str) -> tuple[int, int, int]:
    value = value.lstrip("#")
    return tuple(int(value[i : i + 2], 16) for i in (0, 2, 4))


def rgb_float(rgb: tuple[int, int, int]) -> str:
    return ", ".join(f"{c / 255:.4f}" for c in rgb)


def kiosk_html(ident: dict, colors: dict) -> str:
    return f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{ident["pretty_name"]}</title>
<style>
  :root {{
    --primary: {colors["primary"]};
    --background: {colors["background"]};
    --accent: {colors["accent"]};
    --accent-alt: {colors["accent_alt"]};
    --foreground: {colors["foreground"]};
  }}
  * {{ box-sizing: border-box; }}
  html, body {{ height: 100%; margin: 0; }}
  body {{
    display: flex; flex-direction: column;
    align-items: center; justify-content: center;
    gap: 2vmin;
    font-family: system-ui, "DejaVu Sans", sans-serif;
    color: var(--foreground);
    background: radial-gradient(circle at 50% 30%,
                var(--primary) 0%, var(--background) 70%);
    cursor: none; user-select: none;
  }}
  img {{ width: 28vmin; height: auto; margin-bottom: 1vmin; }}
  h1 {{ margin: 0; font-size: 7vmin; letter-spacing: .05em; }}
  p {{ margin: 0; font-size: 2.6vmin; color: var(--accent); }}
  .rule {{
    width: 26vmin; height: .5vmin; border-radius: 1vmin;
    background: linear-gradient(90deg, var(--accent-alt), var(--accent));
  }}
  footer {{
    position: fixed; bottom: 3vmin;
    font-size: 2vmin; opacity: .75;
  }}
</style>
</head>
<body>
  <img src="logo.png" alt="{ident["pretty_name"]}">
  <h1>{ident["pretty_name"]}</h1>
  <div class="rule"></div>
  <p>version {ident["version"]} &middot; {ident["vendor"]}</p>
  <footer>{ident["support_url"]}</footer>
</body>
</html>
"""


def plymouth_conf(name: str) -> str:
    return "\n".join(
        [
            "[Plymouth Theme]",
            f"Name={name}",
            f"Description={name} boot splash",
            "ModuleName=script",
            "",
            "[script]",
            "ImageDir=/usr/share/plymouth/themes/citos",
            "ScriptFile=/usr/share/plymouth/themes/citos/citos.script",
            "",
        ]
    )


def plymouth_script(colors: dict) -> str:
    bg = rgb_float(hex_to_rgb(colors["background"]))
    return "\n".join(
        [
            "# Generated from common/branding/brand.toml — do not edit.",
            f"Window.SetBackgroundTopColor({bg});",
            f"Window.SetBackgroundBottomColor({bg});",
            "logo = Image(\"logo.png\");",
            "if (logo) {",
            "    logo_sprite = Sprite(logo);",
            "    logo_sprite.SetX(Window.GetWidth() / 2 - logo.GetWidth() / 2);",
            "    logo_sprite.SetY(Window.GetHeight() / 2 - logo.GetHeight() / 2);",
            "}",
            "",
        ]
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--brand", required=True, help="path to brand.toml")
    parser.add_argument("--release", default="trixie")
    parser.add_argument("--out", required=True, help="overlay output directory")
    args = parser.parse_args()

    brand = tomllib.loads(pathlib.Path(args.brand).read_text())
    ident = brand["identity"]
    colors = brand["colors"]
    out = pathlib.Path(args.out)

    (out / "usr/lib").mkdir(parents=True, exist_ok=True)
    (out / "etc").mkdir(parents=True, exist_ok=True)

    os_release = "\n".join(
        [
            f'PRETTY_NAME="{ident["pretty_name"]} {ident["version"]} ({args.release})"',
            f'NAME="{ident["name"]}"',
            f'VERSION_ID="{ident["version"]}"',
            f'VERSION="{ident["version"]} ({args.release})"',
            f"VERSION_CODENAME={args.release}",
            f'ID={ident["id"]}',
            "ID_LIKE=debian raspbian",
            f'HOME_URL="{ident["home_url"]}"',
            f'SUPPORT_URL="{ident["support_url"]}"',
            f'BUG_REPORT_URL="{ident["bug_report_url"]}"',
            f'DOCUMENTATION_URL="{ident["documentation"]}"',
            f'VENDOR_NAME="{ident["vendor"]}"',
            "",
        ]
    )
    (out / "usr/lib/os-release").write_text(os_release)

    (out / "etc/motd").write_text(
        f"\n{BANNER}\n\n"
        f" {ident['pretty_name']} {ident['version']} ({args.release})"
        f" — {ident['vendor']}\n"
        f" Support: {ident['support_url']}\n\n"
    )
    (out / "etc/issue").write_text(
        f"{ident['pretty_name']} {ident['version']} \\n \\l\n"
    )

    kiosk = out / "usr/share/citos/kiosk"
    kiosk.mkdir(parents=True, exist_ok=True)
    (kiosk / "index.html").write_text(kiosk_html(ident, colors))

    theme = out / "usr/share/plymouth/themes/citos"
    theme.mkdir(parents=True, exist_ok=True)
    (theme / "citos.plymouth").write_text(plymouth_conf(ident["pretty_name"]))
    (theme / "citos.script").write_text(plymouth_script(colors))

    print(f"rendered branding into {out}")


if __name__ == "__main__":
    main()
