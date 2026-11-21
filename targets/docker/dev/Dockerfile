# Cybroid OS headless devcontainer image (ADR-0005).
# Built on the same branding/common layer as cybroidos-pod-base, then one
# headless toolchain per stack. No desktop and no default credentials.
FROM debian:trixie-slim

ARG VERSION=0.1.0
ARG HOSTNAME=cybroid
ARG EDITION=core
ARG STACK=generic
# devcontainer.metadata must be a JSON array (devcontainer spec). The build
# script replaces this with stack-specific metadata containing the image ref.
ARG DEVCONTAINER_METADATA=[{"name":"CybroidOSDev","remoteUser":"cybroid"}]

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl wget git jq less procps vim-tiny xz-utils \
      python3 python3-venv sudo openssh-client openssh-server \
    && rm -rf /var/lib/apt/lists/*

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

# Per-stack packages are listed in dev/stacks.json and staged by build.sh.
COPY stack-packages.txt /usr/local/lib/cybroidos/stack-packages.txt
COPY config/install-stack.sh /usr/local/sbin/cybroid-install-stack
RUN chmod 0755 /usr/local/sbin/cybroid-install-stack \
 && /usr/local/sbin/cybroid-install-stack "${STACK}"

# Reference copy for repository users; VS Code normally reads the image label.
COPY devcontainer.json /usr/share/doc/cybroidos-pod-dev/devcontainer.json

LABEL devcontainer.metadata="${DEVCONTAINER_METADATA}" \
      org.opencontainers.image.title="Cybroid OS pod dev (${STACK})" \
      org.opencontainers.image.version="${VERSION}" \
      org.cybroidos.edition="${EDITION}" \
      org.cybroidos.vendor="Cybroid Technologies (U) Ltd" \
      org.cybroidos.stack="${STACK}"

EXPOSE 22

ENTRYPOINT ["/usr/local/bin/cybroid-entrypoint"]
CMD ["sleep", "infinity"]
