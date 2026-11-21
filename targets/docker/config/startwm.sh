#!/bin/sh
# xrdp session startup for Cybroid OS pods: branded, tuned Xfce 4.20.
if [ -r /etc/profile ]; then
	. /etc/profile
fi
if [ -r "$HOME/.profile" ]; then
	. "$HOME/.profile"
fi
if [ -x /usr/bin/cybroidos-xfce-session ]; then
	exec /usr/bin/cybroidos-xfce-session
fi
exec /usr/bin/startxfce4
