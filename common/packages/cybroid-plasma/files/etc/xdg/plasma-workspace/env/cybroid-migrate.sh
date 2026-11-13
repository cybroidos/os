# CybroidOS (cybroid-plasma): an account made under CIT-OS (until 0.1.2) names
# CIT-OS's themes and widgets in its settings: org.cybroid.citos.* widgets,
# the CITOS* colours, the CIT-OS window, dock and Kvantum themes, the citos
# Plasma styles and wallpapers. Plasma runs this before the desktop starts
# (it sources plasma-workspace/env), so the desktop comes up with the new
# names. Once per account; nothing to do for accounts made since.
_cy_cfg="${XDG_CONFIG_HOME:-$HOME/.config}"
if [ ! -e "${_cy_cfg}/cybroid/migrated-from-citos" ] && [ -d "${_cy_cfg}" ]; then
	for _cy_f in plasma-org.kde.plasma.desktop-appletsrc plasmashellrc kdeglobals kwinrc plasmarc \
		kscreenlockerrc ksplashrc Kvantum/kvantum.kvconfig gtk-3.0/settings.ini gtk-4.0/settings.ini \
		kdedefaults/kdeglobals kdedefaults/kwinrc kdedefaults/plasmarc kdedefaults/ksplashrc; do
		[ -f "${_cy_cfg}/${_cy_f}" ] || continue
		grep -qiE 'citos|CIT-OS' "${_cy_cfg}/${_cy_f}" || continue
		sed -i \
			-e 's/org\.cybroid\.citos\./org.cybroid./g' \
			-e 's/CITOSHorizon/CybroidHorizon/g' -e 's/CITOSHex/CybroidHex/g' \
			-e 's/CIT-OS/CybroidOS/g' \
			-e 's|/backgrounds/citos/citos|/backgrounds/cybroid/cybroid|g' \
			-e 's/^name=citos/name=cybroid/' \
			-e 's|/usr/libexec/citos/|/usr/libexec/cybroid/|g' \
			"${_cy_cfg}/${_cy_f}"
	done
	# The dock's launchers point at the renamed copies of the apps.
	for _cy_f in "${_cy_cfg}"/plank/dock1/launchers/*.dockitem; do
		[ -f "${_cy_f}" ] && sed -i -e 's|/usr/share/citos/|/usr/share/cybroid/|g' -e 's|citos-|cybroid-|g' "${_cy_f}"
	done
	# The dock's theme lives in dconf.
	if command -v gsettings >/dev/null 2>&1; then
		_cy_dock=net.launchpad.plank.dock.settings:/net/launchpad/plank/docks/dock1/
		case "$(gsettings get "${_cy_dock}" theme 2>/dev/null)" in
		*CIT-OS*) gsettings set "${_cy_dock}" theme "$(gsettings get "${_cy_dock}" theme | tr -d "'" | sed 's/CIT-OS/CybroidOS/')" 2>/dev/null || true ;;
		esac
	fi
	# First-run markers (the dock's apps, the Templates folder) carry over.
	if [ -d "${_cy_cfg}/citos" ]; then
		mkdir -p "${_cy_cfg}/cybroid"
		cp -an "${_cy_cfg}/citos/." "${_cy_cfg}/cybroid/" 2>/dev/null || true
	fi
	mkdir -p "${_cy_cfg}/cybroid" && : > "${_cy_cfg}/cybroid/migrated-from-citos"
fi
unset _cy_cfg _cy_f _cy_dock

# 0.1.2: the tray of an account made before CybroidOS gave it its own list
# keeps Plasma's full one, with sound, brightness, Wi-Fi and Bluetooth beside
# Control Centre. Trim it to what Control Centre doesn't show, once.
_cy_cfg="${XDG_CONFIG_HOME:-$HOME/.config}"
_cy_rc="${_cy_cfg}/plasma-org.kde.plasma.desktop-appletsrc"
if [ ! -e "${_cy_cfg}/cybroid/tray-0.1.2" ] && [ -f "${_cy_rc}" ]; then
	sed -i -E '/^extraItems=.*org\.kde\.plasma\.(volume|brightness|networkmanagement)/c\
extraItems=org.kde.plasma.notifications,org.kde.plasma.devicenotifier,org.kde.plasma.battery,org.kde.plasma.keyboardlayout,org.kde.plasma.mediacontroller,org.kde.plasma.cameraindicator' "${_cy_rc}"
	mkdir -p "${_cy_cfg}/cybroid" && : > "${_cy_cfg}/cybroid/tray-0.1.2"
fi
unset _cy_cfg _cy_rc
