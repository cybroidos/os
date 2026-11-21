#!/usr/bin/env bash
# Start SSH only when a public key is supplied at runtime.
#
# Sources, in order: CYBROID_SSH_PUBLIC_KEY, a mounted
# /run/secrets/cybroid_ssh_public_key, or a mounted
# /etc/cybroidos/authorized_keys. With none of these, sshd is not started.
set -euo pipefail

authorized="/home/cybroid/.ssh/authorized_keys"
tmp=""

cleanup() {
	[ -z "${tmp}" ] || rm -f "${tmp}"
}

main() {
	trap cleanup EXIT

	install -d -m 0755 /run/sshd
	tmp="$(mktemp)"

	if [ -n "${CYBROID_SSH_PUBLIC_KEY:-}" ]; then
		printf '%s\n' "${CYBROID_SSH_PUBLIC_KEY}" > "${tmp}"
	elif [ -r /run/secrets/cybroid_ssh_public_key ]; then
		cat /run/secrets/cybroid_ssh_public_key > "${tmp}"
	elif [ -r /etc/cybroidos/authorized_keys ]; then
		cat /etc/cybroidos/authorized_keys > "${tmp}"
	else
		echo "note: SSH disabled (supply CYBROID_SSH_PUBLIC_KEY or mount a public key)"
		return 0
	fi

	if [ ! -s "${tmp}" ]; then
		echo "note: SSH disabled (supplied public key was empty)"
		return 0
	fi

	install -d -m 0700 -o cybroid -g cybroid /home/cybroid/.ssh
	cat "${tmp}" > "${authorized}"
	chown cybroid:cybroid "${authorized}"
	chmod 0600 "${authorized}"

	/usr/sbin/sshd
	echo "note: sshd started for user cybroid (pubkey-only)"
}

main "$@"
