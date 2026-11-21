#!/bin/sh
# xrdp session startup for Cybroid OS pods: always launch Xfce 4.20.
if [ -r /etc/profile ]; then
	. /etc/profile
fi
if [ -r "$HOME/.profile" ]; then
	. "$HOME/.profile"
fi
exec startxfce4
