# Signed APT repository

Cybroid OS needs a signed APT repository so security fixes reach devices
without reflashing. This implements ADR-0007 with `reprepro`.

## Layout

```
apt-repo/
  publish.sh        # imports .deb files and exports a signed repo
  public/           # generated: dists/, pool/, conf/ (do not commit)
```

## One-time setup

On the release host (or in CI):

```sh
sudo apt install reprepro gnupg
export GNUPGHOME=/secure/path/to/gnupg
gpg --batch --quick-generate-key "Cybroid OS Release <security@cybroid.com>" \
  rsa3072 sign never
# Store the key ID in CI secret REPO_SIGNING_KEY; keep the private key OUTSIDE
# the repository and never print it in logs.
```

## Publishing

```sh
mkdir -p dist/incoming
tools/build-package.sh cybroidos-base
cp dist/*.deb dist/incoming/
REPO_SIGNING_KEY=<key-id> apt-repo/publish.sh dist/incoming trixie
```

The script writes `dists/<suite>/InRelease` (signed) and `Release.gpg`. Host
`public/` on HTTPS and add this to devices:

```
deb [signed-by=/etc/apt/keyrings/cybroidos.gpg] https://repo.cybroid.com/trixie trixie main
```

## Client verification

Devices must pin the repository and verify the signing key:

```sh
gpg --verify dists/trixie/InRelease
apt-get update
```

## CI

Add `REPO_SIGNING_KEY` and the GPG private key as GitHub Actions secrets with
`contents: read` plus a separate publish workflow that never checks out untrusted
code with write credentials. Nightly builds may publish to a `trixie-testing`
suite; only tagged releases publish to `trixie`.
