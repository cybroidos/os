#!/usr/bin/env bash
# Per-container identity hygiene for Cybroid OS pods.
#
# The image ships an empty /etc/machine-id and no SSH host keys. On the first
# start of each container this script creates a fresh machine-id and host keys.
# The marker lives in the container writable layer, so restarts of the same
# container keep a stable identity while new containers do not share one.
set -euo pipefail

marker="/var/lib/cybroidos/.identity-ready"
hostname_file="/etc/cybroidos/hostname"

main() {
	if [ ! -f "${marker}" ]; then
		install -d -m 0755 /var/lib/cybroidos
		rm -f /etc/ssh/ssh_host_*
		tr -d '\n-' </proc/sys/kernel/random/uuid > /etc/machine-id
		chmod 0644 /etc/machine-id
		ssh-keygen -A >/dev/null
		: > "${marker}"
	fi

	# Docker bind-mounts /etc/hostname; write the branded value as well and
	# pass --hostname cybroid at run time for the kernel hostname.
	local host="cybroid"
	if [ -r "${hostname_file}" ]; then
		read -r host < "${hostname_file}" || true
	fi
	[ -n "${host}" ] || host="cybroid"
	printf '%s\n' "${host}" > /etc/hostname
	if ! grep -Eq "^[[:space:]]*127\\.0\\.1\\.1[[:space:]].*(^|[[:space:]])${host}([[:space:]]|$)" /etc/hosts 2>/dev/null; then
		printf '127.0.1.1 %s\n' "${host}" >> /etc/hosts
	fi
}

main "$@"
