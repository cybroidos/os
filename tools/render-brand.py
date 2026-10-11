#!/usr/bin/env python3
"""Render CIT-OS identity files from common/branding/brand.toml.

Emits `usr/lib/os-release`, `etc/motd` and `etc/issue` into an overlay directory
that pi-gen copies into the image, so branding is defined once (brand.toml) and
flows to the Pi stage (and later the shared <brand>-base package).
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


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--brand", required=True, help="path to brand.toml")
    parser.add_argument("--release", default="trixie")
    parser.add_argument("--out", required=True, help="overlay output directory")
    args = parser.parse_args()

    brand = tomllib.loads(pathlib.Path(args.brand).read_text())
    ident = brand["identity"]
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

    print(f"rendered branding into {out}")


if __name__ == "__main__":
    main()
