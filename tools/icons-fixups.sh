#!/bin/sh
# CIT-OS's changes to the WhiteSur icons (citos-icons), run on the installed
# themes: <dir holding WhiteSur*>. WhiteSur is installed with -a (its own
# file-manager and store icons, not Finder's face); here the photo viewer's
# icon, Apple Photos' flower, becomes WhiteSur's own picture icon, so
# nothing in CIT-OS looks like another company's trademark.
set -eu
root="$1"
for t in "$root"/WhiteSur*; do
	d="$t/apps/scalable"
	[ -d "$d" ] || continue
	pic="$(readlink -f "$d/accessories-image-viewer.svg" 2>/dev/null || true)"
	[ -f "$pic" ] || continue
	for n in multimedia-photo-viewer gpicview Gnome-Photos org.gnome.Photos; do
		f="$(readlink -f "$d/$n.svg" 2>/dev/null || true)"
		[ -f "$f" ] && [ "$f" != "$pic" ] && cp "$pic" "$f"
	done
done
echo "icons-fixups: done"
