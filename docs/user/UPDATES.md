# Updates

Cybroid OS is based on Debian 13 "Trixie". Security updates reach devices
through the signed APT repository described in `docs/APT-REPO.md`.

## Until the signed repository is live

There is no supported in-place update channel yet. Treat each released image as
a complete unit: download the new image, verify its checksum and reflash. Do
not run `apt upgrade` from upstream Debian repositories on a branded image —
that can overwrite Cybroid OS packages and branding.

## When the signed repository is available

```sh
sudo apt update
sudo apt full-upgrade
```

Only the Cybroid OS signing key should be trusted for the `cybroidos` source.
Verify the repository's `InRelease` signature before enabling it. Education
editions use a managed update window; ask your administrator for the schedule.
