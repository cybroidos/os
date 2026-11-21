#!/bin/sh
# xrdp session window manager for Cybroid OS server/pods.
# Same Xfce session used by cybroidos-pod-desktop (ADR-0003/0005).
set -eu

unset DBUS_SESSION_BUS_ADDRESS
unset DBUS_SESSION_BUS_LISTEN
export XDG_CURRENT_DESKTOP=XFCE
export DESKTOP_SESSION=xfce

if [ -x /usr/bin/startxfce4 ]; then
	exec /usr/bin/startxfce4
fi
echo "error: startxfce4 not found (Xfce 4.20 is required)" >&2
exit 1
