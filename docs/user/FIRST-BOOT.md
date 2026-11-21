# First boot

On first boot Cybroid OS automatically:

1. regenerates `/etc/machine-id` and all SSH host keys, so every device is
   unique even though images are cloned;
2. installs an SSH provisioning key if one was supplied, and enables SSH only
   in that case (pubkey-only, no root login);
3. applies the baseline firewall by setting deny-incoming / allow-outgoing
   when `ufw` is present;
4. marks your password as expired so the first interactive login forces you to
   choose a new one;
5. writes `/etc/cybroidos/first-boot-done` and disables the one-time service.

The kiosk edition then boots quietly to the branded splash and launches the
fullscreen kiosk app. Use a secondary console (Ctrl+Alt+F2) for administration.

If a provisioning key was not included, SSH remains disabled until you add one
locally and enable the service.
