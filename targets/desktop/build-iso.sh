#!/usr/bin/env bash
# CybroidOS Desktop as a live and installer ISO (hybrid: DVD or USB stick, BIOS
# and UEFI). It boots silently into the live CybroidOS Desktop (Horizon), signed
# in as "cybroid" (password "cybroid", to try the sign-in screen); "Install
# CybroidOS" in the dock starts Calamares, which puts
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
work="$(build_dir 15)"
trap 'rm -rf "${work}"' EXIT

CYBROID_PACKAGES="cybroid-base cybroid-sources cybroid-artwork cybroid-plymouth-theme cybroid-plasma"
build_debs ${CYBROID_PACKAGES}

lb="${work}/lb"
mkdir -p "${lb}/config/packages.chroot" "${lb}/config/package-lists" \
	"${lb}/config/hooks/normal" "${lb}/config/includes.chroot"
for p in ${CYBROID_PACKAGES}; do
	cp "${repo}/dist/${p}_${VERSION}_all.deb" "${lb}/config/packages.chroot/"
done
if [ -n "${EXTRA_DEBS:-}" ] && ls "${EXTRA_DEBS}"/*.deb >/dev/null 2>&1; then
	cp "${EXTRA_DEBS}"/*.deb "${lb}/config/packages.chroot/"
fi
# The local .debs are installed with the lists below; live-build makes them a
# little repository, so their dependencies resolve from Debian.
printf '%s\n' ${CYBROID_PACKAGES} > "${lb}/config/package-lists/cybroid.list.chroot"
for f in "${lb}"/config/packages.chroot/*.deb; do
	dpkg-deb -f "$f" Package
done | sort -u >> "${lb}/config/package-lists/cybroid.list.chroot"

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
firmware-brcm80211
firmware-mediatek
firmware-libertas
firmware-ti-connectivity
firmware-intel-sound
firmware-intel-graphics
firmware-amd-graphics
firmware-sof-signed
intel-microcode
amd64-microcode
qemu-guest-agent
spice-vdagent
calamares
calamares-settings-debian
cracklib-runtime
squashfs-tools
rsync
grub-efi-amd64-bin
grub-efi-amd64-signed
shim-signed
grub-pc-bin
efibootmgr
os-prober
cryptsetup
cryptsetup-initramfs
util-linux-extra
systemd-timesyncd
keyutils
dosfstools
ntfs-3g
EOF

# The live session signs in by itself (a live-config script: it runs only
# when booted live, so the installed system never inherits it).
mkdir -p "${lb}/config/includes.chroot/usr/lib/live/config"
cat > "${lb}/config/includes.chroot/usr/lib/live/config/2000-cybroid-autologin" <<'EOF'
#!/bin/sh
# CybroidOS live: sign the live user in to Plasma (X11) at once. Written to
# /etc/sddm.conf as well: live-config's own sddm step writes the Wayland
# session there, and that file outranks sddm.conf.d.
user=cybroid
for a in $(cat /proc/cmdline); do
	case "$a" in username=* | live-config.username=*) user="${a#*username=}" ;; esac
done
mkdir -p /etc/sddm.conf.d
printf '[Autologin]\nUser=%s\nSession=plasmax11\n' "${user}" > /etc/sddm.conf.d/zz-cybroid-live.conf
printf '[Autologin]\nUser=%s\nSession=plasmax11\n' "${user}" > /etc/sddm.conf
# An easy password, to try the sign-in screen (sign out): the user's name.
echo "${user}:cybroid" | chpasswd
# The live password is public: no remote desktop on the live system (an
# installed one keeps it, and only over Tower; cybroid-firewall-setup).
systemctl mask xrdp.service xrdp-sesman.service >/dev/null 2>&1 || true
# sudo and the installer without asking.
printf '%s ALL=(ALL) NOPASSWD: ALL\n' "${user}" > /etc/sudoers.d/live
chmod 0440 /etc/sudoers.d/live
# The usual home folders (Documents, Downloads, Music, Pictures, Videos) for
# the live user at once, not only once the session has started.
if id "${user}" >/dev/null 2>&1 && command -v xdg-user-dirs-update >/dev/null; then
	runuser -u "${user}" -- env HOME="/home/${user}" xdg-user-dirs-update --force >/dev/null 2>&1 || true
fi
# A live session has nothing to protect: no screen lock.
mkdir -p /etc/xdg
printf '[Daemon]\nAutolock=false\nLockOnResume=false\n' > /etc/xdg/kscreenlockerrc
EOF
chmod 0755 "${lb}/config/includes.chroot/usr/lib/live/config/2000-cybroid-autologin"

# Calamares in CybroidOS's colours and words.
brand="${lb}/config/includes.chroot/etc/calamares/branding/cybroid"
mkdir -p "${brand}"
cp "${repo}/common/packages/cybroid-plasma/files/usr/share/icons/hicolor/scalable/apps/cybroid-mark.svg" "${brand}/mark.svg"
cat > "${brand}/branding.desc" <<EOF
---
componentName: cybroid
welcomeStyleCalamares: false
welcomeExpandingLogo: true
windowExpanding: normal
windowSize: 960px,620px
windowPlacement: center
sidebar: qml,left
navigation: qml,bottom
strings:
    productName: CybroidOS
    shortProductName: CybroidOS
    version: ${VERSION}
    shortVersion: ${VERSION}
    versionedName: CybroidOS ${VERSION}
    shortVersionedName: CybroidOS ${VERSION}
    bootloaderEntryName: CybroidOS
    productUrl: https://cybroid.com
    supportUrl: https://cybroid.com
    knownIssuesUrl:
    releaseNotesUrl:
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
uploadServer:
    type: none
EOF
# Its look: the stylesheet (every page in the Horizon look), the slideshow
# (screenshots of the system while it installs) and the welcome picture.
cp "${here}/installer/stylesheet.qss" "${here}/installer/show.qml" \
	"${here}/installer/calamares-sidebar.qml" "${here}/installer/calamares-navigation.qml" "${brand}/"
cp -r "${here}/installer/slides" "${brand}/slides"
# GRUB's preparation without apt (Debian's helper installed it with apt-get,
# which a live ISO without a package source can't).
mkdir -p "${lb}/config/includes.chroot/usr/share/calamares/helpers"
install -m 0755 "${here}/installer/calamares-bootloader-config" \
	"${lb}/config/includes.chroot/usr/share/calamares/helpers/calamares-bootloader-config"
# The logo and welcome pictures, rasterised here (Qt's SVG can't draw the mark).
rsvg-convert -w 256 -h 256 "${brand}/mark.svg" -o "${brand}/logo.png"
python3 - "${here}/installer/slides/1-horizon.jpg" "${brand}/welcome.png" <<'PY'
import sys
from PIL import Image
Image.open(sys.argv[1]).convert("RGB").resize((640, 400), Image.LANCZOS).save(sys.argv[2])
PY
rm -f "${brand}/mark.svg"

# Calamares' place: Kampala, without moving the live session's clock.
mkdir -p "${lb}/config/includes.chroot/etc/calamares/modules"
cat > "${lb}/config/includes.chroot/etc/calamares/modules/locale.conf" <<'EOF'
---
region: "Africa"
zone: "Kampala"
adjustLiveTimezone: false
localeGenPath: "/etc/locale.gen"
EOF
# Disks made easy: "Erase disk" is chosen from the start (manual partitioning
# stays, one click away), swap is a file (a 6 GB partition took a quarter of
# a small disk), ext4.
cat > "${lb}/config/includes.chroot/etc/calamares/modules/partition.conf" <<'EOF'
---
efi:
    mountPoint: "/boot/efi"
    recommendedSize: 300MiB
    minimumSize: 32MiB
    label: "EFI"
efiSystemPartition: "/boot/efi"
userSwapChoices: [ none, file ]
initialSwapChoice: file
initialPartitioningChoice: erase
allowManualPartitioning: true
drawNestedPartitions: false
alwaysShowPartitionLabels: true
defaultFileSystemType: "ext4"
availableFileSystemTypes: [ "ext4", "btrfs", "xfs" ]
enableLuksAutomatedPartitioning: true
EOF
# The live system's own packages leave the installed one. try_remove, as
# Debian's "remove" stopped the install at the first name the image lacks
# (live-task-localisation, live-task-recommended): "Package Manager error".
cat > "${lb}/config/includes.chroot/etc/calamares/modules/packages.conf" <<'EOF'
---
backend: apt
update_db: false
update_system: false
operations:
    - try_remove:
        - live-boot
        - live-boot-doc
        - live-config
        - live-config-doc
        - live-config-systemd
        - live-tools
        - live-task-localisation
        - live-task-recommended
        - user-setup
        - calamares-settings-debian
        - calamares
EOF
# A step on the installed system: numbers and dates in British English where
# Calamares picked Luganda's lg_UG from the zone (it isn't generated).
cat > "${lb}/config/includes.chroot/etc/calamares/modules/shellprocess-cybroid.conf" <<'EOF'
---
dontChroot: false
timeout: 60
script:
    - "-sed -i s/lg_UG.UTF-8/en_GB.UTF-8/g /etc/default/locale"
EOF

# After the packages: Calamares uses the CybroidOS branding; its launcher is
# "Install CybroidOS" with the CybroidOS mark.
cat > "${lb}/config/hooks/normal/9000-cybroid.hook.chroot" <<'EOF'
#!/bin/sh
set -e
# New accounts start in zsh (cybroid-plasma's /etc/skel/.zshrc).
if [ -f /etc/calamares/modules/users.conf ]; then
	if grep -q '^userShell:' /etc/calamares/modules/users.conf; then
		sed -i 's|^userShell:.*|userShell: /usr/bin/zsh|' /etc/calamares/modules/users.conf
	else
		echo 'userShell: /usr/bin/zsh' >> /etc/calamares/modules/users.conf
	fi
fi
if [ -f /etc/calamares/settings.conf ]; then
	sed -i 's/^branding:.*/branding: cybroid/' /etc/calamares/settings.conf
	if ! grep -q "shellprocess@cybroid" /etc/calamares/settings.conf; then
		sed -i 's/^  - displaymanager$/  - displaymanager\n  - shellprocess@cybroid/' /etc/calamares/settings.conf
		printf '\ninstances:\n- id: cybroid\n  module: shellprocess\n  config: shellprocess-cybroid.conf\n' >> /etc/calamares/settings.conf
	fi
fi
# Debian 13 names Calamares' launcher calamares-install-debian.desktop; the
# dock looks for install-debian.desktop, so the CybroidOS one is made under that
# name and Debian's is hidden (and its desktop shortcut left out).
src=/usr/share/applications/calamares-install-debian.desktop
if [ -f "$src" ] && [ ! -f /usr/share/applications/install-debian.desktop ]; then
	cp "$src" /usr/share/applications/install-debian.desktop
fi
for f in /usr/share/applications/install-debian.desktop /etc/skel/Desktop/install-debian.desktop; do
	[ -f "$f" ] || continue
	sed -i -e 's/^Name=.*/Name=Install CybroidOS/' -e '/^Name\[/d' \
		-e 's/^GenericName=.*/GenericName=Put CybroidOS on this computer/' -e '/^GenericName\[/d' \
		-e 's/^Comment=.*/Comment=Put CybroidOS on this computer/' -e '/^Comment\[/d' \
		-e 's/^Icon=.*/Icon=cybroid-mark/' "$f"
done
if [ -f "$src" ] && ! grep -q '^NoDisplay=true' "$src"; then
	echo 'NoDisplay=true' >> "$src"
fi
rm -f /etc/xdg/autostart/calamares-desktop-icon.desktop
# No stray blank wallpaper text on the desktop of the live user.
rm -rf /etc/skel/Desktop
EOF
chmod 0755 "${lb}/config/hooks/normal/9000-cybroid.hook.chroot"

# The boot menus (tools/boot-menu.py, put in by tools/iso-brand.sh after the
# build): CybroidOS's own in place of live-build's stock Debian ones.
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
	--cache-packages true \
	--apt-options "--yes -o Acquire::Retries=5 --allow-downgrades" \
	--chroot-squashfs-compression-type zstd \
	--iso-application "CybroidOS" \
	--iso-publisher "Cybroid" \
	--iso-volume "CybroidOS ${VERSION}" \
	--bootappend-live "boot=live components quiet splash loglevel=3 rd.udev.log_level=3 systemd.show_status=false vt.global_cursor_default=0 username=cybroid user-fullname=Cybroid hostname=cybroid keyboard-layouts=us locales=en_GB.UTF-8 timezone=Africa/Kampala"
# --allow-downgrades: once deb.cybroid.com has a package at the version
# built here (plank, the icons, a CybroidOS version being rebuilt), lb
# binary's upgrade swaps the local copy for the published one, which apt
# calls a downgrade (same version, other bytes). The ISO then carries what
# installed machines get.
# live-build's stages one by one: at the end of "chroot" it writes
# /etc/apt/sources.list with Debian's own mirrors (no option turns that
# off), after cybroid-sources has set them aside. Cleared before the ISO is
# made, so the live system and every install use deb.cybroid.com only
# (cybroid.sources).
{
	lb bootstrap && lb chroot &&
	printf '%s\n' '# CybroidOS takes its packages from deb.cybroid.com:' \
		'# see /etc/apt/sources.list.d/cybroid.sources.' > chroot/etc/apt/sources.list &&
	! grep -rlE 'deb\.debian\.org|security\.debian\.org' chroot/etc/apt/sources.list chroot/etc/apt/sources.list.d/ &&
	lb installer && lb binary
} 2>&1 | tail -n 200
iso=\$(ls /build/lb/*.iso | head -1)
sh /build/tools/iso-brand.sh "\$iso" "/out/cybroidos-desktop-${VERSION}-amd64.iso"
EOF
chmod 0755 "${work}/run.sh"

# live-build's downloaded packages stay between builds (about 1,700 .debs;
# fetching them again took most of an hour on Wi-Fi). Only the packages,
# never a built stage: each build starts from a fresh bootstrap. The folder
# is moved into the build and back (live-build hard-links into it, which a
# separate mount would refuse), even when the build fails.
cache="${CYBROID_BUILD_CACHE:-/var/cache/cybroid-build}/live-build"
if [ -d "${cache}" ]; then
	find "${cache}" -name '*.deb' -mtime +30 -delete 2>/dev/null || true
	# live-build keeps the base system too (its installer step reads it);
	# dropped so every build bootstraps fresh.
	rm -rf "${cache}/bootstrap"
	mv "${cache}" "${lb}/cache"
fi
trap 'mkdir -p "$(dirname "${cache}")"; [ -d "${lb}/cache" ] && mv "${lb}/cache" "${cache}"; rm -rf "${work}"' EXIT
docker run --rm --privileged -v "${work}:/build" -v "${out}:/out" debian:trixie /build/run.sh
ls -lh "${out}"/cybroidos-desktop-*-amd64.iso
