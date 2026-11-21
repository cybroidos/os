# Cybroid OS pod base image (ADR-0005).
# debian:trixie-slim + shared branding package + kcd + pubkey-only SSH.
FROM debian:trixie-slim

ARG VERSION=0.1.0
ARG HOSTNAME=cybroid
ARG EDITION=core

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

# Common tooling. No systemd: SSH and desktop services are started by the
# entrypoint, and secrets are never baked into the image.
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl wget git jq less procps vim-tiny xz-utils \
      python3 python3-venv sudo openssh-client openssh-server \
    && rm -rf /var/lib/apt/lists/*

# Shared brand identity (os-release, MOTD, logo assets) from the single source
# common/branding/brand.toml, built by tools/build-package.sh and staged by
# targets/docker/build.sh into this build context.
COPY cybroidos-base.deb /tmp/cybroidos-base.deb
RUN dpkg -i /tmp/cybroidos-base.deb \
    && rm -f /tmp/cybroidos-base.deb \
    && ln -sfn ../usr/lib/os-release /etc/os-release

COPY config/ /usr/local/lib/cybroidos/
COPY config/install-kcd.sh /usr/local/sbin/cybroid-install-kcd
COPY config/first-boot.sh /usr/local/sbin/cybroid-first-boot
COPY config/ssh-entrypoint.sh /usr/local/sbin/cybroid-ssh
COPY config/entrypoint.sh /usr/local/bin/cybroid-entrypoint

RUN chmod 0755 /usr/local/sbin/cybroid-* /usr/local/bin/cybroid-entrypoint \
 && cp /usr/local/lib/cybroidos/sshd_config /etc/ssh/sshd_config \
 && install -d -m 0755 /run/sshd /etc/cybroidos \
 && printf '%s\n' "${HOSTNAME}" > /etc/hostname \
 && printf '%s\n' "${HOSTNAME}" > /etc/cybroidos/hostname \
 && useradd -m -s /bin/bash cybroid \
 && passwd -l cybroid \
 && passwd -l root \
 && rm -f /etc/ssh/ssh_host_* \
 && : > /etc/machine-id \
 && /usr/local/sbin/cybroid-install-kcd

LABEL org.opencontainers.image.title="Cybroid OS pod base" \
      org.opencontainers.image.version="${VERSION}" \
      org.cybroidos.edition="${EDITION}" \
      org.cybroidos.vendor="Cybroid Technologies (U) Ltd"

EXPOSE 22

ENTRYPOINT ["/usr/local/bin/cybroid-entrypoint"]
CMD ["sleep", "infinity"]
