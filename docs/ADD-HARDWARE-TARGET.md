# Adding a hardware target

Every target follows the same shape:

```
targets/<name>/
  build.sh                 # one command from clean checkout to artifact
  config/ or auto/config   # target-specific build config
  hooks/                   # thin overlays only
  README.md                # prerequisites, build, output name, smoke test
tests/<name>/
  smoke-test.sh            # structural + QEMU checks, no root required
```

## Steps

1. Derive all identity from `common/branding/brand.toml`; never hard-code the
   product name, id, hostname or colours.
2. Install the shared `cybroidos-base` package and, where appropriate, a
   `cybroidos-<target>` metapackage. Do not duplicate branding logic.
3. Add first-boot hygiene: regenerate `/etc/machine-id` and SSH host keys, no
   default password, SSH off or pubkey-only, forced password change, baseline
   firewall.
4. Name artifacts `cybroid-os-<edition>-<target>-<arch>-<version>.<ext>` and
   emit a release manifest with
   `tools/release-manifest.sh --edition <edition>`.
5. Add a smoke test that asserts `ID=cybroidos`, hostname `cybroid`, branded
   `/etc/motd` and `/etc/issue`, and branding assets. Provide a `SKIP_BOOT=1`
   mode that inspects artifacts offline when KVM/QEMU is unavailable.
6. Add a workflow under `.github/workflows/` with `permissions: contents: read`
   and upload the artifact + manifest.
7. Update `README.md`, `docs/PLAN.md`, `.github/workflows/ci.yml` required-file
   list and `docs/RELEASE-CHECKLIST.md`.

## Emulation honesty

QEMU is a proxy, not the device. Keep QEMU-only workarounds in `tests/` and
never in shipping images. For Pi targets, `docs/release/HARDWARE-CHECKLIST.md`
must be completed on real hardware before release; a passing QEMU run is never
reported as hardware validation.
