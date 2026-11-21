# cybroidos-control (v0 skeleton)

`cybroidos-control` is the Cybroid OS desktop-side D-Bus service and CLI for the
Android control app described in ADR-0004 (`docs/adr/ADR-0004-mobile-client.md`
in the source repository).
It exposes a small, explicit set of actions to the KDE Connect plugin layer on
the system bus. It does **not** implement the KDE Connect wire protocol; that is
the job of `kdeconnect`/`kcd` and the `cybroidos_connect` Dart package.

This is a **v0 skeleton**. The action surface is implemented, but end-to-end
interoperability with KDE Connect and phone-side RDP clients has not been tested.

## Bus API

| Field | Value |
| --- | --- |
| Bus name | `com.cybroidos.Control` |
| Object path | `/com/cybroidos/Control` |
| Interface | `com.cybroidos.Control` |
| Methods | `Lock`, `OpenUrl(s)`, `OpenApp(s)`, `Notify(ss)`, `GetDeviceInfo`, `StartRemoteView`, `StopRemoteView`, `ListActions`, `GetLastError`, `Status` |

All methods return a boolean (success/failure) except the JSON-returning
information methods. `ListActions()` returns the contents of
`/usr/share/cybroidos/control/actions.json`, which is the action catalogue for
the plugin layer.

## CLI

```sh
cybroidos-control --status                 # JSON status; works even when D-Bus is down
cybroidos-control device-info              # JSON device information
cybroidos-control list-actions             # JSON action catalogue
cybroidos-control lock
cybroidos-control open-url https://example.org/docs
cybroidos-control open-app firefox.desktop
cybroidos-control notify 'Cybroid OS' 'Hello from your phone'
cybroidos-control start-remote-view
cybroidos-control stop-remote-view
cybroidos-control --service                # foreground service (also used by D-Bus autolaunch)
```

### gdbus examples

```sh
gdbus call --system --dest com.cybroidos.Control \
  --object-path /com/cybroidos/Control \
  --method com.cybroidos.Control.Lock

gdbus call --system --dest com.cybroidos.Control \
  --object-path /com/cybroidos/Control \
  --method com.cybroidos.Control.OpenUrl 'https://example.org'

gdbus call --system --dest com.cybroidos.Control \
  --object-path /com/cybroidos/Control \
  --method com.cybroidos.Control.Notify 'Cybroid OS' 'Pairing complete'

gdbus call --system --dest com.cybroidos.Control \
  --object-path /com/cybroidos/Control \
  --method com.cybroidos.Control.GetDeviceInfo

gdbus call --system --dest com.cybroidos.Control \
  --object-path /com/cybroidos/Control \
  --method com.cybroidos.Control.StartRemoteView
```

## Activation and session environment

- D-Bus autolaunch uses `/usr/share/dbus-1/system-services/com.cybroidos.Control.service`
  and the `cybroidos-control.service` systemd unit. The unit is shipped but
  **not enabled automatically** by the package.
- A session `NoDisplay=true` autostart entry is also shipped as a fallback. Both
  launch paths are safe: the second instance exits if the name is already owned.
- Actions that touch the graphical session (`lock`, `open-url`, `open-app`,
  `notify`, KRDP) need `DISPLAY`, `XDG_RUNTIME_DIR` and
  `DBUS_SESSION_BUS_ADDRESS`. Supply them through a systemd drop-in or
  `/etc/cybroidos/control/env` (not shipped, operator-managed). No secrets belong
  in that file.
- Full-screen view uses `systemctl --user start/stop <unit>`. The default unit is
  `krdp-server.service`; override it with `CYBROIDOS_KRDP_UNIT` in the
  environment. Confirm the unit name against the installed KRDP packaging before
  relying on this action. On pods, `kcd` is the headless transport; KRDP is a
  desktop-only recommendation.

## Security notes

- The D-Bus policy in `/etc/dbus-1/system.d/com.cybroidos.Control.conf` grants
  ownership only to the `cybroid` user and method calls only to `cybroid` and
  `kcd`. Everyone else is denied. Both users must exist on the image.
- No action requires root. External programs are started with explicit argv
  lists and `shell=False`; user input is never interpolated into a command line.
- URLs must be absolute `http`/`https` without embedded credentials; app ids must
  match a desktop-file-id pattern **and** appear in the `openAppAllowlist` in
  `actions.json`. Text fields reject control characters and length overruns.
- The catalogue is the allowlist: set `"enabled": false` on an action in
  `/etc/cybroidos/control/actions.json` to disable it locally.
- `GetLastError()` returns the most recent action failure detail. Keep error text
  free of secrets when extending the service.

## Known limitations (v0)

- No KDE Connect packet/TLS interop test has happened yet; the plugin layer is a
  contract, not a proven integration.
- KRDP availability on Android RDP clients needs verification; upstream research
  notes historically mixed results for Microsoft's Android RDP client.
- No remote input, clipboard, notifications bridge, SMS/calls or photo sync yet.
