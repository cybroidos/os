#!/bin/sh
# iso-brand.sh <in.iso> <out.iso> [hook.sh]: give a CybroidOS live ISO its own
# boot menus (tools/boot-menu.py) in place of live-build's stock Debian ones,
# without unpacking or rebuilding it. Needs xorriso, python3, rsvg-convert;
# no root. BIOS (syslinux) and UEFI (GRUB) booting are kept as they were.
#
#   GRUB and syslinux: "Try or install CybroidOS", "Try CybroidOS with safe
#   graphics" (nomodeset), Utilities; the first starts by itself after 5 s.
#
# With hook.sh, the script is put on the medium at /live/config-hooks/ and
# the live system runs it at boot (live-config's hooks=): a way to patch an
# ISO that is already out without touching its system image.
set -eu
in="$1" out="$2" hook="${3:-}"
here="$(cd "$(dirname "$0")" && pwd)"
work="$(mktemp -d)"
trap 'chmod -R u+w "${work}" 2>/dev/null; rm -rf "${work}"' EXIT

xorriso -osirrox on -indev "${in}" -extract /boot/grub "${work}/grub" \
	-extract /isolinux "${work}/isolinux" -extract /sha256sum.txt "${work}/sha256sum.txt" >/dev/null 2>&1
chmod -R u+w "${work}"
python3 "${here}/boot-menu.py" "${work}" >/dev/null

hookarg=""
if [ -n "${hook}" ]; then
	hookarg=" hooks=file:///run/live/medium/live/config-hooks/$(basename "${hook}")"
fi

# The entries: names, a safe-graphics entry with the live options and
# nomodeset, one copied into memory (toram: the whole system read once
# from the stick at boot, then at memory speed; live-boot falls back to the
# stick when memory is short), the hook, no beep, a 5 s timeout.
python3 - "${work}" "${hookarg}" <<'PY'
import pathlib, re, sys
root, hookarg = pathlib.Path(sys.argv[1]), sys.argv[2]

g = root / "grub" / "grub.cfg"
s = g.read_text()
live = re.search(r'menuentry "Live system \(amd64\)".*?\n\s*linux\s+(\S+)\s+(.*?)\n\s*initrd\s+(\S+)', s, re.S)
kernel, opts, initrd = live.group(1), live.group(2), live.group(3)
opts = opts.replace(hookarg.strip(), "").rstrip() + hookarg
main = (f'menuentry "Try or install CybroidOS" --hotkey=t {{\n\tlinux\t{kernel} {opts}\n\tinitrd\t{initrd}\n}}\n'
        f'menuentry "Try CybroidOS from memory (smoother on slow USB sticks)" --hotkey=m {{\n\tlinux\t{kernel} {opts} toram\n\tinitrd\t{initrd}\n}}\n'
        f'menuentry "Try CybroidOS with safe graphics" --hotkey=s {{\n\tlinux\t{kernel} {opts} nomodeset\n\tinitrd\t{initrd}\n}}\n')
s = re.sub(r'# Live boot\n.*?(?=\n# You can add more entries)', "# Live boot\n" + main, s, flags=re.S)
g.write_text(s)

c = root / "grub" / "config.cfg"
s = c.read_text()
s = re.sub(r"\ninsmod play\nplay [^\n]*", "", s)
# GRUB's terminal once an entry is chosen: full screen over the same
# picture (the theme puts it there), so no box is drawn over the mark
# (cybroid-plasma's 06_cybroid_background does the same on an installed system).
s = re.sub(r'\nbackground_color "[^"]*"', "", s)
if "background_image" not in s:
    s = s.rstrip("\n") + "\nbackground_image -m stretch /boot/grub/splash.png\n"
if "set timeout=" not in s:
    s = s.replace("set default=0", "set default=0\nset timeout=5\nset timeout_style=menu")
c.write_text(s)

l = root / "isolinux" / "live.cfg"
s = l.read_text()
append = re.search(r"label live-amd64\n.*?append ([^\n]*)", s, re.S).group(1)
append = append.replace(hookarg.strip(), "").rstrip() + hookarg
s = ("label live-amd64\n\tmenu label ^Try or install CybroidOS\n\tmenu default\n\tlinux /live/vmlinuz\n"
     f"\tinitrd /live/initrd.img\n\tappend {append}\n\n"
     "label live-amd64-toram\n\tmenu label Try CybroidOS from ^memory (smoother on slow USB sticks)\n\tlinux /live/vmlinuz\n"
     f"\tinitrd /live/initrd.img\n\tappend {append} toram\n\n"
     "label live-amd64-safe\n\tmenu label Try CybroidOS with ^safe graphics\n\tlinux /live/vmlinuz\n"
     f"\tinitrd /live/initrd.img\n\tappend {append} nomodeset\n")
l.write_text(s)

i = root / "isolinux" / "isolinux.cfg"
i.write_text(re.sub(r"(?m)^timeout \d+", "timeout 50", i.read_text()))
m = root / "isolinux" / "menu.cfg"
s = m.read_text()
s = re.sub(r"(?m)^menu hshift \d+", "menu hshift 18", s)
s = re.sub(r"(?m)^menu width \d+\n", "", s)
s = re.sub(r"(?m)^menu title Boot menu", "menu title", s)
m.write_text(s)
PY

# The medium's checksums ("Verify integrity" in Utilities) for what changed.
maps=""
changed="boot/grub/grub.cfg boot/grub/config.cfg boot/grub/splash.png boot/grub/live-theme/theme.txt
boot/grub/live-theme/select_c.png boot/grub/live-theme/select_w.png
boot/grub/live-theme/clear_c.png boot/grub/live-theme/clear_n.png boot/grub/live-theme/clear_s.png
boot/grub/live-theme/clear_e.png boot/grub/live-theme/clear_w.png boot/grub/live-theme/clear_nw.png
boot/grub/live-theme/clear_ne.png boot/grub/live-theme/clear_sw.png boot/grub/live-theme/clear_se.png
isolinux/live.cfg isolinux/isolinux.cfg
isolinux/menu.cfg isolinux/stdmenu.cfg isolinux/splash.png"
mkdir -p "${work}/tree/boot" "${work}/tree/live/config-hooks"
mv "${work}/grub" "${work}/tree/boot/grub"
mv "${work}/isolinux" "${work}/tree/isolinux"
if [ -n "${hook}" ]; then
	cp "${hook}" "${work}/tree/live/config-hooks/$(basename "${hook}")"
	chmod 0755 "${work}/tree/live/config-hooks/$(basename "${hook}")"
	changed="${changed} live/config-hooks/$(basename "${hook}")"
fi
for f in ${changed}; do
	sum=$(sha256sum "${work}/tree/${f}" | cut -d' ' -f1)
	grep -v "  \./${f}\$" "${work}/sha256sum.txt" > "${work}/s.tmp" || true
	echo "${sum}  ./${f}" >> "${work}/s.tmp"
	mv "${work}/s.tmp" "${work}/sha256sum.txt"
	maps="${maps} -map ${work}/tree/${f} /${f}"
done
rm -f "${out}"
# shellcheck disable=SC2086
xorriso -indev "${in}" -outdev "${out}" -boot_image any replay \
	${maps} -map "${work}/sha256sum.txt" /sha256sum.txt >/dev/null 2>&1
echo "wrote ${out}"
