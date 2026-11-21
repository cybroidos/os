# Container smoke tests

`smoke-test.sh` verifies the ADR-0005 pod images on amd64 and arm64. For every
selected image and architecture it builds the image, starts a short-lived
container, and checks:

- `/etc/os-release` contains `ID=cybroidos`;
- `/etc/hostname` is the branded hostname from `common/branding/brand.toml`;
- `/usr/share/cybroidos/branding` exists;
- `kcd` is on `PATH`;
- neither `cybroid` nor `root` has a usable password, sshd is not running
  without a supplied key, and no authorized keys are baked in;
- desktop images additionally contain `xrdp`, `Xvfb`, `x11vnc`, `websockify`,
  `startxfce4`, the noVNC web assets, and `xrdp.ini`.

```bash
# Everything, both architectures (builds each image first)
tests/container/smoke-test.sh

# One architecture / one image / one dev stack
ARCH=amd64 tests/container/smoke-test.sh
tests/container/smoke-test.sh --arch arm64 --image desktop
tests/container/smoke-test.sh --image dev --stack python

# Reuse images already loaded by targets/docker/build.sh (used in CI)
tests/container/smoke-test.sh --arch amd64 --image base --skip-build
```

Requirements: a working `docker` CLI (or set `DOCKER` to another CLI), and
whatever `targets/docker/build.sh` needs when building. No `sudo` is used; the
user must be able to talk to the Docker daemon. `REGISTRY`, `TAG` and `EDITION`
must match the values used for the build.

The script always removes its containers, including on failure. A non-zero exit
code means at least one check failed.
