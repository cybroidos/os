#!/bin/sh
# CIT-OS's changes to the WhiteSur icons (citos-icons), run on the installed
# themes: <dir holding WhiteSur*>. WhiteSur is installed with -a (its own
# file-manager and store icons, not Finder's face); here the photo viewer's
# icon, Apple Photos' flower, becomes WhiteSur's own picture icon, and the
# system logo (start-here*, which WhiteSur draws as Apple's logo) and any
# Apple-named icon are removed, the Templates folder (App Store "A") gets a
# plain folder, so CIT-OS's own mark (citos-plasma ships it
# under the start-here names in hicolor) is found instead. Nothing in CIT-OS
# looks like another company's trademark.
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
for t in "$root"/WhiteSur*; do
	find "$t" \( -name 'start-here*' -o -iname '*apple*' \) \( -type f -o -type l \) -delete
	# The Templates folder's icon carries the App Store's "A": a plain folder.
	find "$t" -name 'folder-templates*.svg' \( -type f -o -type l \) | while read -r f; do
		plain="$(dirname "$f")/folder$(basename "$f" | sed 's/^folder-templates//')"
		if [ -e "$plain" ]; then
			rm -f "$f"
			cp "$(readlink -f "$plain")" "$f"
		fi
	done
done
echo "icons-fixups: done"
