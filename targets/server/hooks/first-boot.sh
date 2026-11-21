#!/bin/sh
# Cybroid OS server/pods first-boot identity hygiene.
#
# Installed as /usr/bin/cybroidos-first-boot and called both by the cloud-init
# user-data runcmd and by cybroidos-first-boot.service (ConditionFirstBoot).
# It is idempotent: the flag file makes repeat calls harmless.
#
# - unique machine-id and SSH host keys for every cloned image
# - no default password; any later password must be changed at first login
# - baseline firewall: deny inbound, allow outbound, then open only the
#   documented RDP/noVNC/KDE Connect ports from RFC1918 networks
# - SSH remains public-key only (see sshd_config.d/90-cybroidos.conf)
set -eu

FLAG=/etc/cybroidos/first-boot-done
ADMIN_USER=cybroid
RDP_PORT=3389
NOVNC_PORT=6080

[ -e "${FLAG}" ] && exit 0
# shellcheck disable=SC1091  # installed into the image, not present at lint time
if [ -r /etc/cybroidos/server.conf ]; then
	. /etc/cybroidos/server.conf
fi
: "${ADMIN_USER:=cybroid}"
: "${RDP_PORT:=3389}"
: "${NOVNC_PORT:=6080}"

echo "cybroidos-first-boot: regenerating machine identity"
if [ -r /proc/sys/kernel/random/uuid ]; then
	cat /proc/sys/kernel/random/uuid > /etc/machine-id
else
	: > /etc/machine-id
fi
mkdir -p /var/lib/dbus
ln -sf /etc/machine-id /var/lib/dbus/machine-id

echo "cybroidos-first-boot: regenerating SSH host keys"
rm -f /etc/ssh/ssh_host_*
if command -v ssh-keygen >/dev/null 2>&1; then
	ssh-keygen -A >/dev/null 2>&1 || true
fi

# No password is ever baked into the image. chage -d 0 means that if an
# operator later sets one, it must be changed at the first interactive login.
if command -v chage >/dev/null 2>&1; then
	chage -d 0 "${ADMIN_USER}" 2>/dev/null || true
fi

echo "cybroidos-first-boot: applying baseline firewall"
if command -v ufw >/dev/null 2>&1; then
	ufw default deny incoming >/dev/null 2>&1 || true
	ufw default allow outgoing >/dev/null 2>&1 || true
	for net in 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16; do
		ufw allow from "${net}" to any port "${RDP_PORT}" proto tcp >/dev/null 2>&1 || true
		ufw allow from "${net}" to any port "${NOVNC_PORT}" proto tcp >/dev/null 2>&1 || true
		ufw allow from "${net}" to any port 1716 proto tcp >/dev/null 2>&1 || true
		ufw allow from "${net}" to any port 1716 proto udp >/dev/null 2>&1 || true
		ufw allow from "${net}" to any port 1739:1764 proto tcp >/dev/null 2>&1 || true
	done
	ufw --force enable >/dev/null 2>&1 || true
fi

if command -v systemctl >/dev/null 2>&1; then
	systemctl restart ssh.service >/dev/null 2>&1 || true
fi

mkdir -p /etc/cybroidos
date -u +"%Y-%m-%dT%H:%M:%SZ" > "${FLAG}"
echo "cybroidos-first-boot: complete (no default password; pubkey-only SSH)"
