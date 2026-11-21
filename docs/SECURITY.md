# Security policy — Cybroid OS

Cybroid Technologies (U) Ltd takes the security of Cybroid OS seriously.

## Supported versions

Security fixes are applied to the latest released image and the current
`main` branch of this repository. Older images must be reflashed or upgraded
through the signed APT repository once it is live (see `docs/APT-REPO.md`).

## Reporting a vulnerability

**Do not open a public issue for a security problem.**

Email **security@cybroid.com** with:

- a description of the issue and its impact;
- the affected edition, version and target;
- steps to reproduce, and a proof of concept if you have one.

You will receive an acknowledgement within **3 business days**. We aim to
triage and confirm severity within **10 business days**, and to publish a fix
or mitigation within **30 days** for critical/high issues and **90 days** for
moderate/low issues, depending on complexity.

Please give us a reasonable window to fix the issue before public disclosure.
We will credit reporters who wish to be named.

## Scope

- The build system, packages and image definitions in this repository.
- Released Cybroid OS images (Core, Education, Developer, Professional and
  Enterprise editions).
- The signed update channel and release infrastructure.

Out of scope: third-party upstream Debian packages (report those to Debian),
and deployments modified by the customer after installation.

## Hardening commitments

- No default passwords or default SSH keys in any released image.
- SSH disabled by default; pubkey-only when enabled; no root login.
- Machine ID and SSH host keys regenerated on first boot.
- Release artifacts carry signed checksums and an SBOM.
- CI runs with least privilege and pinned actions.

See `docs/SECURITY-POSTURE.md` for the current assessment and open work.
