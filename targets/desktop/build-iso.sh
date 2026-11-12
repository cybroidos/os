#!/usr/bin/env bash
# CIT-OS Desktop as a live and installer ISO (hybrid: DVD or USB stick, BIOS
# and UEFI). It boots silently into the live CIT-OS Desktop (Horizon), signed
# in as "student"; "Install CIT-OS" in the dock starts Calamares, which puts
# the same system on the disk. Built by Debian's live-build in a Debian 13
# container, from the same packages as the VM image. Built by CI
# (.github/workflows/server-images.yml, the "iso" image).
#
#   sudo OUT=out EXTRA_DEBS=dist/extra targets/desktop/build-iso.sh
#
# Env: OUT (out/), EXTRA_DEBS (other .debs for the image: the dock, icons,
# rounded corners; the same folder the VM build uses).
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "${here}/../.." && pwd)"
# shellcheck source=../lib/image.sh
. "${repo}/targets/lib/image.sh"
need docker python3

out="${OUT:-${repo}/out}"
mkdir -p "${out}"
work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT

CITOS_PACKAGES="citos-base citos-sources citos-artwork citos-plymouth-theme citos-plasma"
build_debs ${CITOS_PACKAGES}

lb="${work}/lb"
mkdir -p "${lb}/config/packages.chroot" "${lb}/config/package-lists" \
	"${lb}/config/hooks/normal" "${lb}/config/includes.chroot"
for p in ${CITOS_PACKAGES}; do
	cp "${repo}/dist/${p}_${VERSION}_all.deb" "${lb}/config/packages.chroot/"
done
if [ -n "${EXTRA_DEBS:-}" ] && ls "${EXTRA_DEBS}"/*.deb >/dev/null 2>&1; then
	cp "${EXTRA_DEBS}"/*.deb "${lb}/config/packages.chroot/"
fi
# The local .debs are installed with the lists below; live-build makes them a
# little repository, so their dependencies resolve from Debian.
printf '%s\n' ${CITOS_PACKAGES} > "${lb}/config/package-lists/citos.list.chroot"
for f in "${lb}"/config/packages.chroot/*.deb; do
	dpkg-deb -f "$f" Package
done | sort -u >> "${lb}/config/package-lists/citos.list.chroot"

# What a real computer needs beyond the VM image: hardware (graphics, Wi-Fi,
# firmware, microcode), networking for people (NetworkManager with Plasma's
# applet), and the live system and installer.
cat > "${lb}/config/package-lists/desktop.list.chroot" <<'EOF'
live-boot
live-config
live-config-systemd
user-setup
sudo
locales
keyboard-configuration
console-setup
xserver-xorg
xserver-xorg-video-all
xserver-xorg-input-all
libgl1-mesa-dri
mesa-vulkan-drivers
network-manager
plasma-nm
bluez
plasma-pa
firmware-linux-free
firmware-misc-nonfree
firmware-iwlwifi
firmware-realtek
firmware-atheros
firmware-amd-graphics
firmware-sof-signed
intel-microcode
amd64-microcode
qemu-guest-agent
spice-vdagent
calamares
calamares-settings-debian
grub-efi-amd64-bin
grub-efi-amd64-signed
shim-signed
grub-pc-bin
efibootmgr
os-prober
cryptsetup
dosfstools
ntfs-3g
EOF

# The live session signs in by itself (a live-config script: it runs only
# when booted live, so the installed system never inherits it).
mkdir -p "${lb}/config/includes.chroot/usr/lib/live/config"
cat > "${lb}/config/includes.chroot/usr/lib/live/config/2000-citos-autologin" <<'EOF'
#!/bin/sh
# CIT-OS live: sign the live user in to Plasma (X11) at once. Written to
# /etc/sddm.conf as well: live-config's own sddm step writes the Wayland
# session there, and that file outranks sddm.conf.d.
user=student
for a in $(cat /proc/cmdline); do
	case "$a" in username=* | live-config.username=*) user="${a#*username=}" ;; esac
done
mkdir -p /etc/sddm.conf.d
printf '[Autologin]\nUser=%s\nSession=plasmax11\n' "${user}" > /etc/sddm.conf.d/zz-citos-live.conf
printf '[Autologin]\nUser=%s\nSession=plasmax11\n' "${user}" > /etc/sddm.conf
# A live session has no password to unlock with: no screen lock.
mkdir -p /etc/xdg
printf '[Daemon]\nAutolock=false\nLockOnResume=false\n' > /etc/xdg/kscreenlockerrc
EOF
chmod 0755 "${lb}/config/includes.chroot/usr/lib/live/config/2000-citos-autologin"

# Calamares in CIT-OS's colours and words.
brand="${lb}/config/includes.chroot/etc/calamares/branding/citos"
mkdir -p "${brand}"
cp "${repo}/common/packages/citos-plasma/files/usr/share/icons/hicolor/scalable/apps/citos-mark.svg" "${brand}/mark.svg"
cat > "${brand}/branding.desc" <<EOF
---
componentName: citos
welcomeStyleCalamares: true
welcomeExpandingLogo: true
windowExpanding: normal
windowSize: 900px,620px
windowPlacement: center
sidebar: widget
navigation: widget
strings:
    productName: CIT-OS
    shortProductName: CIT-OS
    version: ${VERSION}
    shortVersion: ${VERSION}
    versionedName: CIT-OS ${VERSION}
    shortVersionedName: CIT-OS ${VERSION}
    bootloaderEntryName: CIT-OS
    productUrl: https://cybroid.com
    supportUrl: https://cybroid.com
    knownIssuesUrl: https://cybroid.com
    releaseNotesUrl: https://cybroid.com
    donateUrl:
images:
    productLogo: "logo.png"
    productIcon: "logo.png"
    productWelcome: "welcome.png"
slideshow: "show.qml"
slideshowAPI: 2
style:
    SidebarBackground: "#0d1530"
    SidebarText: "#eef3ff"
    SidebarTextCurrent: "#ffffff"
    SidebarBackgroundCurrent: "#1f5fe0"
EOF
cat > "${brand}/show.qml" <<'EOF'
/* CIT-OS installer slideshow: one calm slide while files copy. */
import QtQuick 2.0
import calamares.slideshow 1.0

Presentation {
    id: presentation
    function onActivate() {}
    function onLeave() {}
    Slide {
        Rectangle { anchors.fill: parent; color: "#0d1530" }
        Image {
            id: mark
            source: "logo.png"
            width: 140; height: 140
            fillMode: Image.PreserveAspectFit
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -40
        }
        Text {
            anchors.top: mark.bottom; anchors.topMargin: 24
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Installing CIT-OS"
            color: "#eef3ff"; font.pixelSize: 24
        }
        Text {
            anchors.top: mark.bottom; anchors.topMargin: 62
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Your apps, labs and Hangar, ready when this finishes."
            color: "#a9b8da"; font.pixelSize: 15
        }
    }
}
EOF
# The logo and welcome pictures, rasterised here (Qt's SVG can't draw the mark).
rsvg-convert -w 256 -h 256 "${brand}/mark.svg" -o "${brand}/logo.png"
python3 "${repo}/tools/render-brand.py" --target desktop --only wallpaper --out "${work}/wall" >/dev/null
python3 - "${work}/wall/usr/share/backgrounds/${ID:-citos}/citos-1920x1080.png" "${brand}/welcome.png" <<'PY'
import sys
from PIL import Image
Image.open(sys.argv[1]).resize((640, 360), Image.LANCZOS).save(sys.argv[2])
PY
rm -f "${brand}/mark.svg"

# After the packages: Calamares uses the CIT-OS branding; its launcher is
# "Install CIT-OS" with the CIT-OS mark.
cat > "${lb}/config/hooks/normal/9000-citos.hook.chroot" <<'EOF'
#!/bin/sh
set -e
if [ -f /etc/calamares/settings.conf ]; then
	sed -i 's/^branding:.*/branding: citos/' /etc/calamares/settings.conf
fi
# Debian 13 names Calamares' launcher calamares-install-debian.desktop; the
# dock looks for install-debian.desktop, so the CIT-OS one is made under that
# name and Debian's is hidden (and its desktop shortcut left out).
src=/usr/share/applications/calamares-install-debian.desktop
if [ -f "$src" ] && [ ! -f /usr/share/applications/install-debian.desktop ]; then
	cp "$src" /usr/share/applications/install-debian.desktop
fi
for f in /usr/share/applications/install-debian.desktop /etc/skel/Desktop/install-debian.desktop; do
	[ -f "$f" ] || continue
	sed -i -e 's/^Name=.*/Name=Install CIT-OS/' -e '/^Name\[/d' \
		-e 's/^GenericName=.*/GenericName=Put CIT-OS on this computer/' -e '/^GenericName\[/d' \
		-e 's/^Comment=.*/Comment=Put CIT-OS on this computer/' -e '/^Comment\[/d' \
		-e 's/^Icon=.*/Icon=citos-mark/' "$f"
done
if [ -f "$src" ] && ! grep -q '^NoDisplay=true' "$src"; then
	echo 'NoDisplay=true' >> "$src"
fi
rm -f /etc/xdg/autostart/calamares-desktop-icon.desktop
# No stray blank wallpaper text on the desktop of the live user.
rm -rf /etc/skel/Desktop
EOF
chmod 0755 "${lb}/config/hooks/normal/9000-citos.hook.chroot"

# The boot menus (tools/boot-menu.py, put in by tools/iso-brand.sh after the
# build): CIT-OS's own in place of live-build's stock Debian ones.
mkdir -p "${work}/tools"
cp "${repo}/tools/iso-brand.sh" "${repo}/tools/boot-menu.py" "${work}/tools/"

# The live-build run itself, inside Debian 13.
cat > "${work}/run.sh" <<EOF
#!/bin/sh
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update -q
apt-get install -y -q --no-install-recommends live-build debootstrap squashfs-tools xorriso \
	grub-pc-bin grub-efi-amd64-bin grub-efi-amd64-signed shim-signed mtools dosfstools \
	syslinux syslinux-common isolinux ca-certificates python3 librsvg2-bin fonts-dejavu-core >/dev/null
cd /build/lb
lb config \
	--distribution trixie \
	--archive-areas "main contrib non-free non-free-firmware" \
	--mirror-bootstrap http://deb.debian.org/debian \
	--mirror-binary http://deb.debian.org/debian \
	--security true --updates true \
	--debian-installer none \
	--binary-images iso-hybrid \
	--bootloaders "syslinux,grub-efi" \
	--linux-flavours amd64 \
	--firmware-chroot true --firmware-binary true \
	--apt-recommends false \
	--apt-indices false \
	--chroot-squashfs-compression-type zstd \
	--iso-application "CIT-OS" \
	--iso-publisher "Cybroid Institute of Technology" \
	--iso-volume "CIT-OS ${VERSION}" \
	--bootappend-live "boot=live components quiet splash loglevel=3 rd.udev.log_level=3 systemd.show_status=false vt.global_cursor_default=0 username=student user-fullname=Student hostname=citos locales=en_GB.UTF-8 timezone=Africa/Kampala"
lb build 2>&1 | tail -n 200
iso=\$(ls /build/lb/*.iso | head -1)
sh /build/tools/iso-brand.sh "\$iso" "/out/citos-desktop-${VERSION}-amd64.iso"
EOF
chmod 0755 "${work}/run.sh"

docker run --rm --privileged -v "${work}:/build" -v "${out}:/out" debian:trixie /build/run.sh
ls -lh "${out}"/citos-desktop-*-amd64.iso
