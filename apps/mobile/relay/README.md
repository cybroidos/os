# WireGuard internet relay (v0)

This is a **provisioning sketch**, not a deployed service. It provides the
self-hosted "internet" path from ADR-0004: the phone joins a WireGuard tunnel to
a relay host, which can then reach the Cybroid desktop on the LAN.

```
 phone (WireGuard client)
        |
        | encrypted tunnel over the internet
        v
 relay host (wg0, 10.99.0.1/24)
        |
        | LAN routing (operator-managed)
        v
 Cybroid desktop / pod on the LAN (KDE Connect or kcd)
```

KDE Connect itself has no NAT traversal. In this model the relay is an ordinary
WireGuard peer that makes the phone appear on a routable VPN subnet; LAN
forwarding and discovery across that subnet are still an open integration item
(KDE Connect expects UDP/1716 discovery, which does not cross subnets without
help). Treat this as the first step toward internet control, not a finished
relay service.

## Contents

- `wg-relay.conf.example` — placeholder-only WireGuard config template.
- `setup-relay.sh` — generates keypairs and writes configs with mode `0600`.
  Requires `wg` from `wireguard-tools`.

## Usage

```sh
./setup-relay.sh ./generated
```

The script never prints private keys and writes only into the chosen output
directory (`umask 077`, `chmod 0600`). The output directory is gitignored.
Review the generated configs, distribute the peer config securely, and add the
peer's public key to the relay config as instructed by the script output.

## Operator responsibilities

The following are deliberately **not** configured by the skeleton:

- Firewall rules (allow UDP/`51820` on the relay; restrict management access).
- Port forwarding on the relay's upstream router.
- IP forwarding/NAT and routing from the VPN subnet to the LAN.
- Key distribution, rotation, revocation and lifetime policy.
- Persistent relay service enablement (`wg-quick@wg0`) and monitoring.

No keys, endpoints or credentials are committed here. Replace every
`<PLACEHOLDER>` with values from your own deployment.
