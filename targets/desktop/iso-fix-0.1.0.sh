#!/bin/sh
# CIT-OS 0.1.0 live ISO, fixed at boot (tools/iso-brand.sh puts this on the
# medium and adds hooks= to the boot entries). The ISO itself is fixed in
# build-iso.sh; this is for the copies already made.
#
#  - The live user: live-config needs the user-setup package to create it,
#    which the 0.1.0 image lacks, so there was no "student" and nobody was
#    signed in.
#  - The sign-in: into Plasma on X11 (live-config's /etc/sddm.conf named the
#    Wayland session, and it outranks sddm.conf.d).
#  - "Install CIT-OS" missing from the dock (Calamares' launcher's new name).
#  - The black screen: citos-plymouth-theme's "plymouth quit --retain-splash"
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
printf '[Autologin]\nUser=%s\nSession=plasmax11\n' "${user}" > /etc/sddm.conf.d/zz-citos-live.conf

rm -f /usr/lib/systemd/system/plymouth-quit.service.d/retain-splash.conf
systemctl daemon-reload

# "Install CIT-OS", first in the dock: Debian 13 names Calamares' launcher
# calamares-install-debian.desktop; the dock and the build looked for
# install-debian.desktop, so it was missing. Debian's own desktop shortcut
# for it is left out (the dock has it).
src=/usr/share/applications/calamares-install-debian.desktop
if [ -f "${src}" ]; then
	sed -e 's/^Name=.*/Name=Install CIT-OS/' -e '/^Name\[/d' \
		-e 's/^GenericName=.*/GenericName=Put CIT-OS on this computer/' -e '/^GenericName\[/d' \
		-e 's/^Comment=.*/Comment=Put CIT-OS on this computer/' -e '/^Comment\[/d' \
		-e 's/^Icon=.*/Icon=citos-mark/' "${src}" > /usr/share/applications/install-debian.desktop
	grep -q '^NoDisplay=true' "${src}" || echo 'NoDisplay=true' >> "${src}"
fi
rm -f /etc/xdg/autostart/calamares-desktop-icon.desktop

# The installed system: the same drop-in goes, and the live-only sign-in.
if [ -f /etc/calamares/settings.conf ] && ! grep -q "shellprocess@citos" /etc/calamares/settings.conf; then
	cat > /etc/calamares/modules/shellprocess-citos.conf <<'EOF'
---
dontChroot: false
timeout: 60
script:
    - "-rm -f /usr/lib/systemd/system/plymouth-quit.service.d/retain-splash.conf"
    - "-rm -f /etc/sddm.conf.d/zz-citos-live.conf"
EOF
	sed -i 's/^  - displaymanager$/  - displaymanager\n  - shellprocess@citos/' /etc/calamares/settings.conf
	printf '\ninstances:\n- id: citos\n  module: shellprocess\n  config: shellprocess-citos.conf\n' >> /etc/calamares/settings.conf
fi
