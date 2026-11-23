# Components that are not open source

This is the one place that records software in a CybroidOS image, or used by
it, that is not free software. Nothing proprietary is kept in this
repository. Add an entry here before adding such a component to any build.

| Component | Licence | In this repository | In the desktop image | Why |
|---|---|---|---|---|
| Device firmware and CPU microcode (`firmware-*` from Debian's `non-free-firmware`, `intel-microcode`, `amd64-microcode`) | Each vendor's redistribution licence | No | Yes | Wi-Fi, graphics and sound on real laptops need them, as on Debian's own images since Debian 12. Packaged and signed by Debian; their copyright files are in `/usr/share/doc/<package>/`. |
| Kali's container image (Security edition's "Kali tools") | Kali's packages, each under its own licence; a few are proprietary freeware (Burp Suite Community) | No | No | Downloaded from Kali only when the person opens "Kali tools"; never on an ISO. |
| Hangar (Cybroid's management service) | Cybroid Technologies (U) Ltd | No | No | CybroidOS can be enrolled into an organisation's Hangar; the service itself is not part of the operating system. |

## Rules

1. No proprietary binary or source is committed under `common/`, `targets/`,
   `tools/` or `docs/`.
2. A build step that would fetch or install a component not listed here must
   be guarded by `INCLUDE_PROPRIETARY=1` and call `tools/check-proprietary.sh`.
3. Release notes link this page, so people know what is and isn't free software.
4. Prefer open alternatives; when none exists, record how to remove the
   component.
