# Development environments

How CybroidOS is built and tested. The **canonical environment is the
devcontainer** (`.devcontainer/`), which is a **Debian 13 "Trixie"** image — the
same base OS we ship (ADR-0001). "Works in the devcontainer" is the definition of
a working build.

Run `tools/preflight.sh` (also run automatically on devcontainer create) to see
which tools are present.

---

## 1. Canonical: devcontainer (any host with Docker)

`.devcontainer/Dockerfile` installs the full toolchain: `debootstrap`/`mmdebstrap`,
`qemu-*`, `live-build`, `docker` CLI, branding tools (`rsvg-convert`,
ImageMagick), and `shellcheck`. `devcontainer.json`:

- mounts the host Docker socket (so pod/container builds use the host daemon),
- runs `tools/preflight.sh` after create,
- adds ShellCheck/YAML/Docker VS Code extensions.

**Use (VS Code / Codespaces):** open the repo → *Dev Containers: Reopen in
Container*.

**Use (CLI, no VS Code):**
```bash
docker build -t cybroid-build .devcontainer
docker run --rm -it \
  -v "$PWD":/workspaces/cit-os \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -w /workspaces/cit-os cybroid-build bash
```

> Building images that need privileged helpers (e.g. `qemu-user-static` binfmt
> registration, loop mounts) may need `--privileged`. Prefer the host daemon and
> keep privileged steps in CI or a dedicated build host.

---

## 2. Windows main machine

- Install **Docker Desktop** with the **WSL2 backend**, then use the devcontainer
  (above). There is **no native Windows build path** — everything runs in Linux.
- The Docker socket mount works transparently through Docker Desktop.

## 3. WSL2 (direct, without VS Code)

- Inside a WSL2 distro with Docker available, either run the CLI devcontainer
  (above) or install the toolchain directly with the same package list as
  `.devcontainer/Dockerfile`.
- Point `DOCKER_HOST`/the socket mount at the WSL2 Docker engine.

## 4. GCP x86 VM (8 vCPU, 32 GB)

Full builds for **desktop ISO**, **server/pods**, **pod images**, and the **Pi
image** (cross/QEMU, slower).

```bash
# On a Debian 13 VM:
sudo apt-get update
sudo apt-get install -y ca-certificates git curl python3 debootstrap mmdebstrap \
  qemu-user-static qemu-system-arm qemu-system-aarch64 qemu-utils binfmt-support \
  live-build squashfs-tools libarchive-tools dosfstools parted kpartx fdisk \
  librsvg2-bin imagemagick optipng xz-utils zip unzip shellcheck
```

## 5. GCP arm64 VM (e.g. Tau T2A) — fast native Pi builds

An **arm64** VM is the **fast native path** for the Pi image (no
`qemu-user-static` emulation). Prefer this for Pi work when available. Same
package list as the x86 VM (drop the `qemu-user-static`/`binfmt` bits if you are
not cross-building).

## 6. Deepin laptop — local testing (QEMU 8.2)

Used for the QEMU test scripts in `tests/qemu/`. This box has **QEMU 8.2**, which
exposes only `raspi0/1/2/3` (no `raspi4b`) and whose `raspi4b` (elsewhere) lacks
GENET Ethernet and has a keyboard-input bug. Therefore **test scripts must
feature-detect the available `-M` machines** (never hard-code `raspi4b`):

```bash
qemu-system-aarch64 -M help | grep -E 'raspi[0-9]b' || true
```

QEMU-only workarounds stay in a **test profile** and are **never** reported as
hardware validation (PLAN ground rule 4).

---

## 7. What each environment is for

| Environment | Pi image | Desktop ISO | Server/pods | Pod images | Tests |
|---|---|---|---|---|---|
| devcontainer (x86 host) | cross/QEMU | yes | yes | yes | smoke |
| WSL2 (x86) | cross/QEMU | yes | yes | yes | smoke |
| GCP x86 VM | cross/QEMU | yes | yes | yes | smoke/KVM |
| GCP **arm64** VM | **native (fast)** | optional | optional | optional | smoke |
| Deepin laptop | — | — | — | — | **QEMU scripts only** |
