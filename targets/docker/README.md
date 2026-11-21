# Cybroid OS pod images (Phase 4)

Container images implementing [ADR-0005](../../docs/adr/ADR-0005-pod-image-variants.md):

| Image | Purpose |
|---|---|
| `cybroidos-pod-base` | `debian:trixie-slim` + `cybroidos-base` branding + `kcd` + pubkey-only SSH. No desktop. |
| `cybroidos-pod-dev-generic`, `cybroidos-pod-dev-python`, `cybroidos-pod-dev-node` | Headless devcontainers. Each ships a `devcontainer.metadata` label (a JSON array) and a `devcontainer.json` template. |
| `cybroidos-pod-desktop` | Xfce 4.20 + xrdp (primary) + noVNC (fallback) + `kcd`, with the shared branded Xfce look and video-tuned session wrapper from `tools/render-xfce-brand.py`. |

All images are built for **linux/amd64** and **linux/arm64**. There are no
proprietary components and no secrets in the repository.

## Build

Requirements: `python3`, Debian packaging tools (`dpkg-dev`, `debhelper`,
`fakeroot`), and Docker with `buildx` plus registered binfmt/QEMU for cross-arch
builds. `podman` is used as a fallback when `docker buildx` is unavailable.

```bash
# All images, both architectures, loaded into the local engine
targets/docker/build.sh

# One architecture / one image / one dev stack
targets/docker/build.sh --arch amd64
targets/docker/build.sh --arch arm64 --stack python dev
targets/docker/build.sh --stack node dev
targets/docker/build.sh desktop

# Push a multi-arch manifest to the registry
PUSH=1 targets/docker/build.sh
```

Environment:

- `PUSH=0|1` — push to `REGISTRY` instead of loading locally (default `0`).
- `TAG` — image tag; defaults to `identity.version` in `common/branding/brand.toml`.
- `EDITION` — validated against `editions/<edition>/config`; adds an OCI label
  and a `:${TAG}-${EDITION}` alias tag (default `core`). It is metadata only:
  every ADR-0005 image variant is still produced.
- `REGISTRY` — default `ghcr.io/cybroidtech`.
- `REBUILD_PACKAGE=1` — force a rebuild of the `cybroidos-base` `.deb`.

The build script calls `tools/build-package.sh cybroidos-base`, then stages that
`.deb`, the shared `config/` tree, and each Dockerfile into
`targets/docker/.context/<image>/`. Generated contexts are ignored by git.

Local (non-push) builds are tagged per architecture, for example
`ghcr.io/cybroidtech/cybroidos-pod-desktop:0.1.0-amd64`. Pushed builds get a
single multi-arch manifest at
`ghcr.io/cybroidtech/cybroidos-pod-desktop:0.1.0` (Docker buildx only; the
podman fallback pushes per-architecture tags).

## Run

Docker supplies the kernel hostname at container creation, so pass
`--hostname cybroid` to match the branded `/etc/hostname` written by the image.

```bash
# Headless base pod; SSH stays off because no key was supplied
docker run -d --name cybroid-pod --hostname cybroid \
  ghcr.io/cybroidtech/cybroidos-pod-base:0.1.0-amd64

# Enable SSH at runtime (pubkey-only, root login disabled)
docker run -d --name cybroid-dev --hostname cybroid \
  -e CYBROID_SSH_PUBLIC_KEY="$(cat ~/.ssh/id_ed25519.pub)" \
  -p 2222:22 \
  ghcr.io/cybroidtech/cybroidos-pod-dev-python:0.1.0-amd64

# Desktop pod: RDP 3389 and noVNC 6080
docker run -d --name cybroid-desktop --hostname cybroid \
  -p 3389:3389 -p 6080:6080 \
  ghcr.io/cybroidtech/cybroidos-pod-desktop:0.1.0-amd64
```

Ports:

| Port | Service | Notes |
|---|---|---|
| 22 | sshd | Only started when a public key is supplied at runtime. |
| 3389 | xrdp | Primary RDP path. RDP uses PAM, so set a password for `cybroid` at runtime if you need RDP login; none is baked in. |
| 5901 | x11vnc | Internal VNC display `:99`, normally not published. |
| 6080 | noVNC | Browser fallback: `http://localhost:6080/vnc.html`. |

SSH key sources, in order: `CYBROID_SSH_PUBLIC_KEY`,
`/run/secrets/cybroid_ssh_public_key`, `/etc/cybroidos/authorized_keys` (the
last two are intended as runtime mounts). With no key, `sshd` is not started.
Authorized keys are installed for the unprivileged `cybroid` user; SSH is
pubkey-only with `PermitRootLogin no`.

On first start each container regenerates `/etc/machine-id` and its SSH host
keys. A marker in the writable layer keeps the identity stable across restarts
of the same container.

## VS Code / devcontainers

VS Code's Dev Containers extension reads the `devcontainer.metadata` image
label (a JSON array) when you open a folder in a container image, so no local
configuration is required. To pin a stack explicitly, set the image in your
project's `.devcontainer/devcontainer.json`:

```json
{
  "image": "ghcr.io/cybroidtech/cybroidos-pod-dev-python:0.1.0",
  "remoteUser": "cybroid"
}
```

The repository template `dev/devcontainer.json` uses
`"${env:CYBROID_POD_IMAGE}"`; export that variable to the image tag you want:

```bash
export CYBROID_POD_IMAGE=ghcr.io/cybroidtech/cybroidos-pod-dev-node:0.1.0
```

`dev/stacks.json` is the catalogue for the `--stack` option and the per-stack
package lists. It is also used to generate the metadata label.

## Notes / limitations

- `kcd` is not in Debian Trixie. The build installs upstream `kcd` v2.0.1
  amd64/arm64 `.deb` assets, pinned by SHA-256 in `config/install-kcd.sh`.
- The podman fallback builds per-architecture tags; use Docker buildx to
  publish a single multi-arch manifest.
- Xvfb/Xfce/x11vnc run as `cybroid`; `xrdp` runs as root only to bind port 3389.
