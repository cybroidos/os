#!/bin/sh
# CybroidOS 0.1.0 live ISO, fixed at boot (tools/iso-brand.sh puts this on the
# medium and adds hooks= to the boot entries). The ISO itself is fixed in
# build-iso.sh; this is for the copies already made.
#
#  - The live user: live-config needs the user-setup package to create it,
#    which the 0.1.0 image lacks, so there was no "student" and nobody was
#    signed in.
#  - The sign-in: into Plasma on X11 (live-config's /etc/sddm.conf named the
#    Wayland session, and it outranks sddm.conf.d).
#  - "Install CybroidOS" missing from the dock (Calamares' launcher's new name).
#  - The installer: no password could pass (no cracklib dictionary in the
#    image: "error loading dictionary"), so the dictionary check is off; it
#    could not unpack the system (no unsquashfs), so it copies it with rsync;
#    Kampala as the place, the live clock left alone; numbers and dates in
#    British English (Luganda's lg_UG, picked from the zone, isn't generated).
#  - The black screen: cybroid-plymouth-theme's "plymouth quit --retain-splash"
#    (for the kiosk) left the console to a display manager that never takes
#    it, so SDDM's X server waited for its VT for ever. Removed here, before
#    Plymouth quits, and from the installed system by a Calamares step.
user=student
if ! id "${user}" >/dev/null 2>&1; then
	adduser --disabled-password --gecos Student "${user}" >/dev/null
fi
passwd -d "${user}" >/dev/null
for g in sudo audio video netdev plugdev users lpadmin bluetooth; do
	adduser "${user}" "${g}" >/dev/null 2>&1 || true
done
printf '%s ALL=(ALL) NOPASSWD: ALL\n' "${user}" > /etc/sudoers.d/live
chmod 0440 /etc/sudoers.d/live
printf '[Autologin]\nUser=%s\nSession=plasmax11\n' "${user}" > /etc/sddm.conf
mkdir -p /etc/sddm.conf.d
printf '[Autologin]\nUser=%s\nSession=plasmax11\n' "${user}" > /etc/sddm.conf.d/zz-cybroid-live.conf

rm -f /usr/lib/systemd/system/plymouth-quit.service.d/retain-splash.conf
systemctl daemon-reload

# "Install CybroidOS", first in the dock: Debian 13 names Calamares' launcher
# calamares-install-debian.desktop; the dock and the build looked for
# install-debian.desktop, so it was missing. Debian's own desktop shortcut
# for it is left out (the dock has it).
src=/usr/share/applications/calamares-install-debian.desktop
if [ -f "${src}" ]; then
	sed -e 's/^Name=.*/Name=Install CybroidOS/' -e '/^Name\[/d' \
		-e 's/^GenericName=.*/GenericName=Put CybroidOS on this computer/' -e '/^GenericName\[/d' \
		-e 's/^Comment=.*/Comment=Put CybroidOS on this computer/' -e '/^Comment\[/d' \
		-e 's/^Icon=.*/Icon=cybroid-mark/' "${src}" > /usr/share/applications/install-debian.desktop
	grep -q '^NoDisplay=true' "${src}" || echo 'NoDisplay=true' >> "${src}"
fi
rm -f /etc/xdg/autostart/calamares-desktop-icon.desktop

# The installer's settings (the 0.1.0 image has no cracklib dictionary).
users=/etc/calamares/modules/users.conf
if [ -f "${users}" ] && ! grep -q dictcheck "${users}"; then
	sed -i 's/^\(\s*\)- minclass=0$/\1- minclass=0\n\1- dictcheck=0/' "${users}"
fi
cat > /etc/calamares/modules/locale.conf <<'EOF'
---
region: "Africa"
zone: "Kampala"
adjustLiveTimezone: false
localeGenPath: "/etc/locale.gen"
EOF
sed -i 's/^welcomeStyleCalamares: true/welcomeStyleCalamares: false/' /etc/calamares/branding/cybroid/branding.desc 2>/dev/null || true
# Unpacking: the 0.1.0 image has no unsquashfs ("Failed to find unsquashfs"),
# so the installer copies the mounted system with rsync instead.
if ! command -v unsquashfs >/dev/null && [ -d /run/live/rootfs/filesystem.squashfs ]; then
	cat > /etc/calamares/modules/unpackfs.conf <<'EOF'
---
unpack:
    -   source: "/run/live/rootfs/filesystem.squashfs/"
        sourcefs: "file"
        destination: ""
EOF
fi

# GRUB: Debian's helper installed it with apt-get, which this ISO has no
# source for ("grub-efi has no installation candidate"). The image has GRUB;
# this only gives the new system its settings and menu.
helper=/usr/share/calamares/helpers/calamares-bootloader-config
if [ -f "${helper}" ] && grep -q 'apt-get -y install grub' "${helper}"; then
	cat > "${helper}" <<'HELPER'
#!/bin/bash
CHROOT=$(mount | grep proc | grep calamares | awk '{print $3}' | sed -e "s#/proc##g")
[ -n "${CHROOT}" ] || exit 1
echo "Running bootloader-config (CybroidOS)..."
if [ ! -f "${CHROOT}/etc/default/grub" ] && [ -f "${CHROOT}/usr/share/grub/default/grub" ]; then
	cp "${CHROOT}/usr/share/grub/default/grub" "${CHROOT}/etc/default/grub"
fi
if [ -f "${CHROOT}/etc/default/grub" ] && ! grep -q '^GRUB_DISABLE_OS_PROBER=' "${CHROOT}/etc/default/grub"; then
	echo 'GRUB_DISABLE_OS_PROBER=false' >> "${CHROOT}/etc/default/grub"
fi
mkdir -p "${CHROOT}/boot/grub"
chroot "${CHROOT}" /usr/sbin/update-grub || true
exit 0
HELPER
	chmod 0755 "${helper}"
fi

# Removing the live packages: try_remove, as "remove" stopped the install at
# the first name the image lacks ("Package Manager error").
if [ -f /etc/calamares/modules/packages.conf ]; then
	sed -i 's/^\(\s*-\s*\)remove:/\1try_remove:/' /etc/calamares/modules/packages.conf
fi

# The installed system: the same drop-in goes, and the live-only sign-in.
if [ -f /etc/calamares/settings.conf ] && ! grep -q "shellprocess@cybroid" /etc/calamares/settings.conf; then
	cat > /etc/calamares/modules/shellprocess-cybroid.conf <<'EOF'
---
dontChroot: false
timeout: 60
script:
    - "-rm -f /usr/lib/systemd/system/plymouth-quit.service.d/retain-splash.conf"
    - "-rm -f /etc/sddm.conf.d/zz-cybroid-live.conf"
    - "-sed -i s/lg_UG.UTF-8/en_GB.UTF-8/g /etc/default/locale"
EOF
	sed -i 's/^  - displaymanager$/  - displaymanager\n  - shellprocess@cybroid/' /etc/calamares/settings.conf
	printf '\ninstances:\n- id: cybroid\n  module: shellprocess\n  config: shellprocess-cybroid.conf\n' >> /etc/calamares/settings.conf
fi
