#!/usr/bin/env bash
# Entrypoint for cybroidos-pod-desktop (ADR-0005).
#
# Starts Xvfb + Xfce for the noVNC path, x11vnc + websockify for the browser
# fallback, and xrdp as the primary remote-desktop path. Runs as PID 1 and
# keeps the container alive. Xvfb/Xfce/x11vnc run as the unprivileged cybroid
# user; xrdp needs root for port 3389.
set -euo pipefail

config_dir="/usr/local/lib/cybroidos"
# shellcheck source=/dev/null
. "${config_dir}/novnc.env"

main() {
	/usr/local/sbin/cybroid-first-boot
	/usr/local/sbin/cybroid-ssh

	local uid runtime_dir
	uid="$(id -u cybroid)"
	runtime_dir="/run/user/${uid}"
	install -d -m 0700 -o cybroid -g cybroid "${runtime_dir}"

	local -a pids=()

	runuser -u cybroid -- Xvfb "${VNC_DISPLAY}" \
		-screen 0 "${VNC_GEOMETRY}" -nolisten tcp &
	pids+=("$!")
	sleep 1

	runuser -u cybroid -- env DISPLAY="${VNC_DISPLAY}" \
		XDG_RUNTIME_DIR="${runtime_dir}" \
		dbus-launch --exit-with-session startxfce4 &
	pids+=("$!")

	runuser -u cybroid -- x11vnc -display "${VNC_DISPLAY}" \
		-rfbport "${VNC_PORT}" -localhost -forever -shared -nopw &
	pids+=("$!")

	websockify --web="${NOVNC_WEB}" \
		"0.0.0.0:${NOVNC_PORT}" "127.0.0.1:${VNC_PORT}" &
	pids+=("$!")

	/usr/sbin/xrdp-sesman &
	pids+=("$!")
	/usr/sbin/xrdp --nodaemon &
	pids+=("$!")

	trap 'kill "${pids[@]}" >/dev/null 2>&1 || true' EXIT INT TERM
	echo "Cybroid OS desktop pod ready (RDP 3389, noVNC ${NOVNC_PORT})"
	wait
}

main "$@"
