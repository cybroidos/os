# Recovery

## Lost administrator password

There is no default password to fall back to. Use your SSH provisioning key
(if one was installed) to log in and run `passwd`. Otherwise boot from a
recovery medium, mount the root filesystem and reset the account, or reflash
the image.

## Kiosk app will not start

The kiosk is launched by `/usr/bin/cybroidos-kiosk`. Check:

```sh
systemctl status getty@tty1
cat /etc/cybroidos/kiosk.conf
journalctl -u getty@tty1 -n 50
```

The default mode is `cage-chromium`; an alternative `flutter` mode needs a
Flutter bundle at `/usr/share/cybroidos/kiosk/flutter_bundle`. Switch modes by
editing `/etc/cybroidos/kiosk.conf` as root.

## Device identity duplicated after cloning

Run `sudo /usr/bin/cybroidos-first-boot` after removing
`/etc/cybroidos/first-boot-done`, then reboot. This regenerates the machine ID
and SSH host keys.

## Reflash

Download the image for your edition, verify the SHA-256 in `manifest.md`, flash
it and boot again. Configuration in `/etc/cybroidos/` should be backed up first.
