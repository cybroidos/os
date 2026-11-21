# Proprietary components register

This is the single place where software that is **not** open source is recorded.
Nothing in this list may be added to the source repository itself. A component
may only appear in a published image if its entry explicitly says it is shipped
and under what terms.

| Component | Licence / source | In source repo | In public image | Notes |
|---|---|---|---|---|
| Hangar | Vendor EULA (proprietary) | No | No by default | Windows-side application used in some deployments. If a customer requires it, ship as a separate opt-in download with its own EULA; do not bundle into the public ISO. |

## Rules

1. No proprietary binary or source is committed under `common/`, `targets/`,
   `tools/` or `docs/`.
2. Any build script that would fetch or install a non-free component must
   guard it behind an explicit flag (for example `INCLUDE_PROPRIETARY=1`) and
   print a warning.
3. Every shipped image must include this register in its release notes so users
   know exactly what is and is not free software.
4. Add new entries here before adding the component to any build target.
5. Prefer open alternatives. If a proprietary component is unavoidable,
   document the replacement path and removal instructions.

## Hangar

Hangar is referenced here because it is a real proprietary tool used in the
wider environment but it is **not** part of Cybroid OS. It must not be implied to
be open source, and it must not be baked into a public Cybroid OS image. If a
future release bundles it, this table must be updated first and the image
must carry the vendor EULA.
