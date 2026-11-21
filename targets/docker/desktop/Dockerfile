# Cybroid OS desktop pod image (ADR-0005).
# Xfce 4.20 + xrdp (primary) + noVNC (fallback) + kcd. Same brand layer as the
# base/dev images; no proprietary components and no default passwords.
FROM debian:trixie-slim

ARG VERSION=0.1.0
ARG HOSTNAME=cybroid
ARG EDITION=core

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

# Desktop session and remote access. x11vnc mirrors the single Xvfb/Xfce
# session to noVNC; xrdp starts its own Xorg session via /etc/xrdp/startwm.sh.
RUN apt-get update && apt-get install -y --no-install-recommends \
      xfce4 xfce4-session xfce4-terminal xfce4-screensaver xfconf gtk3 \
      xrdp xorgxrdp ssl-cert \
      xvfb x11vnc xauth dbus-x11 x11-xserver-utils \
      novnc websockify \
    && rm -rf /var/lib/apt/lists/*

COPY config/xrdp.ini /etc/xrdp/xrdp.ini
COPY config/startwm.sh /etc/xrdp/startwm.sh
COPY config/novnc.env /usr/local/lib/cybroidos/novnc.env
COPY config/xfce/ /usr/local/lib/cybroidos/xfce/
COPY config/desktop-entrypoint.sh /usr/local/bin/cybroid-desktop-entrypoint

# Install the shared branded Xfce look (wallpaper, backdrop, GTK accent,
# tuned session wrapper and Xsession entry). All values come from brand.toml.
RUN chmod 0755 /etc/xrdp/startwm.sh /usr/local/bin/cybroid-desktop-entrypoint \
 && sh /usr/local/lib/cybroidos/xfce/install.sh / /usr/local/lib/cybroidos/xfce \
 && install -m 0644 /usr/local/lib/cybroidos/xsession /etc/skel/.xsession \
 && install -m 0755 -o cybroid -g cybroid \
      /usr/local/lib/cybroidos/xsession /home/cybroid/.xsession

LABEL org.opencontainers.image.title="Cybroid OS pod desktop" \
      org.opencontainers.image.version="${VERSION}" \
      org.cybroidos.edition="${EDITION}" \
      org.cybroidos.vendor="Cybroid Technologies (U) Ltd"

EXPOSE 22 3389 5901 6080

ENTRYPOINT ["/usr/local/bin/cybroid-desktop-entrypoint"]
