#!/usr/bin/env bash
# Common entrypoint for the headless Cybroid OS pod images.
set -euo pipefail

/usr/local/sbin/cybroid-first-boot
/usr/local/sbin/cybroid-ssh

if [ "$#" -eq 0 ]; then
	set -- sleep infinity
fi
exec "$@"
