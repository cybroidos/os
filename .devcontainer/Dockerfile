# CIT-OS build environment (Debian 13 "Trixie")
# Matches the shipping base OS (ADR-0001). See docs/dev-environments.md.
FROM debian:13-slim

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

# Toolchain for every target in docs/PLAN.md:
#   - general: git/curl/python/build tools
#   - Pi image: debootstrap, mmdebstrap, qemu-user-static, binfmt-support
#   - desktop ISO: live-build, squashfs-tools, libarchive-tools (bsdtar)
#   - server/pod VM tests: qemu-system-*, qemu-utils, parted/kpartx
#   - container/pod images: docker CLI (talks to the mounted host socket)
#   - branding: librsvg2-bin (rsvg-convert), imagemagick, optipng
#   - lint: shellcheck
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates git curl wget gnupg \
      python3 python3-pip python3-venv \
      build-essential make cmake pkg-config \
      debootstrap mmdebstrap \
      qemu-user-static qemu-system-arm qemu-system-aarch64 \
      qemu-utils binfmt-support \
      live-build squashfs-tools libarchive-tools \
      dosfstools parted kpartx fdisk \
      docker.io \
      librsvg2-bin imagemagick optipng \
      xz-utils zstd zip unzip file rsync \
      locales sudo shellcheck \
    && rm -rf /var/lib/apt/lists/*

# Canonical workspace for the devcontainer; the repo is mounted at /workspaces/cit-os.
WORKDIR /workspaces/cit-os
