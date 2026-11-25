#!/usr/bin/env bash
# Builds the packages CybroidOS Desktop takes from outside Debian into
# dist/extra, each in a Debian 13 container: the rounded-corners effect, our
# own apps (Cybroid.Ui, Settings, Camera), Tower's client, ONLYOFFICE (the
# ISO only), the dock (Plank with an edge gap) and the icons. The same
# commands for GitHub (.github/workflows/server-images.yml) and Hangar's
# Forgejo (.forgejo/workflows/images.yml).
#
# Usage: tools/build-extras.sh <part>...    parts: corners apps tower office dock icons docker
#        tools/build-extras.sh desktop      everything a desktop image needs
#        tools/build-extras.sh iso          desktop, and ONLYOFFICE
# Needs docker; run from anywhere (it works in the repository's root).
set -euo pipefail
cd "$(dirname "$0")/.."

# Build the rounded-corners effect
corners() {
	mkdir -p dist/extra
	docker run --rm -v "$PWD/dist/extra:/out" -e VERSION=v0.11.0 debian:trixie sh -ec '
	  apt-get update -q
	  apt-get install -y -q --no-install-recommends ca-certificates git cmake g++ gettext extra-cmake-modules \
	    qt6-base-private-dev qt6-base-dev-tools libkf6configwidgets-dev libkf6kcmutils-dev kwin-dev libdrm-dev dpkg-dev file >/dev/null
	  for try in 1 2 3 4 5; do git clone -q --depth 1 --branch "$VERSION" https://github.com/matinlotfali/KDE-Rounded-Corners /src && break; rm -rf /src; echo "clone failed (try $try), again in 30 s"; sleep 30; done
	  [ -d /src ]
	  cd /src && cmake . -DCMAKE_BUILD_TYPE=Release >/dev/null && cmake --build . -j"$(nproc)" >/dev/null && cpack -G DEB >/dev/null
	  cp kwin4_effect_shapecorners*.deb /out/cybroid-kwin-effects_amd64.deb'
	ls -la dist/extra
}

# Build CybroidOS's own apps
apps() {
	mkdir -p dist/extra
	docker run --rm -v "$PWD:/src" -w /src -e HOST_UID="$(id -u)" debian:trixie sh -ec '
	  apt-get update -q
	  apt-get install -y -q --no-install-recommends cmake g++ make dpkg-dev python3 \
	    qt6-base-dev qt6-declarative-dev qt6-multimedia-dev >/dev/null
	  tools/build-native.sh /src/dist/extra
	  chown -R "$HOST_UID" /src/dist'
	ls -la dist/extra
}

# Fetch the Tower client
tower() {
	tools/fetch-tailscale.sh dist/extra
}

# Fetch ONLYOFFICE, checked against its signing key
office() {
	tools/fetch-onlyoffice.sh dist/extra
}

# Fetch Docker Engine for the Developer and Security editions, checked
# against Docker's signing key, into dist/vendor: published to deb.cybroid.com
# (tools/ci-publish.sh) but not put in the ISO, which carries no edition
docker_ce() {
	tools/fetch-docker.sh dist/vendor
}

# Build the dock (Plank with an edge gap)
dock() {
	docker run --rm -v "$PWD/dist/extra:/out" -v "$PWD/tools:/tools:ro" debian:trixie sh -ec '
	  printf "Types: deb deb-src\nURIs: http://deb.debian.org/debian\nSuites: trixie trixie-updates\nComponents: main\nSigned-By: /usr/share/keyrings/debian-archive-keyring.gpg\n\nTypes: deb deb-src\nURIs: http://deb.debian.org/debian-security\nSuites: trixie-security\nComponents: main\nSigned-By: /usr/share/keyrings/debian-archive-keyring.gpg\n" > /etc/apt/sources.list.d/debian.sources
	  apt-get update -q
	  apt-get install -y -q --no-install-recommends dpkg-dev devscripts python3 >/dev/null
	  apt-get build-dep -y -q plank >/dev/null
	  mkdir /src && cd /src && apt-get source -q plank >/dev/null && cd plank-*/
	  python3 /tools/plank-edge-gap.py .
	  DEBEMAIL=citos@cybroid.com DEBFULLNAME=CybroidOS dch -l +cybroid "Float a bottom dock above the edge of the screen (PLANK_EDGE_GAP)." >/dev/null
	  DEB_BUILD_OPTIONS="nocheck parallel=$(nproc)" dpkg-buildpackage -b -uc -us >/dev/null
	  cp ../plank_*+cybroid*_amd64.deb ../libplank1_*+cybroid*_amd64.deb ../libplank-common_*+cybroid*_all.deb /out/'
	ls -la dist/extra
}

# Build the icons (cybroid-icons)
icons() {
	docker run --rm -v "$PWD/dist/extra:/out" -v "$PWD/tools:/tools:ro" -e REF=2026-09-10 debian:trixie sh -ec '
	  apt-get update -q
	  apt-get install -y -q --no-install-recommends ca-certificates git gtk-update-icon-cache libgtk-3-bin >/dev/null 2>&1 || apt-get install -y -q --no-install-recommends ca-certificates git >/dev/null
	  useradd -m build
	  for try in 1 2 3 4 5; do su build -c "git clone -q --depth 1 --branch $REF https://github.com/vinceliuice/WhiteSur-icon-theme /home/build/src" && break; rm -rf /home/build/src; echo "clone failed (try $try), again in 30 s"; sleep 30; done
	  su build -c "test -d /home/build/src && mkdir -p /home/build/out && cd /home/build/src && ./install.sh -a -d /home/build/out -n WhiteSur >/dev/null"
	  sh /tools/icons-fixups.sh /home/build/out
	  apt-get install -y -q --no-install-recommends python3 python3-pil librsvg2-bin >/dev/null
	  python3 /tools/icons-dark.py /home/build/out
	  p=/home/build/pkg; mkdir -p $p/DEBIAN $p/usr/share/icons $p/usr/share/doc/cybroid-icons
	  cp -a /home/build/out/WhiteSur* $p/usr/share/icons/
	  cp /home/build/src/COPYING $p/usr/share/doc/cybroid-icons/copyright 2>/dev/null || cp /home/build/src/LICENSE $p/usr/share/doc/cybroid-icons/copyright
	  printf "Package: cybroid-icons\nVersion: %s\nArchitecture: all\nMaintainer: CybroidOS <citos@cybroid.com>\nSection: x11\nPriority: optional\nReplaces: citos-icons\nBreaks: citos-icons\nProvides: citos-icons\nDescription: CybroidOS app icons (WhiteSur, %s)\n Rounded-square app icons for CybroidOS Desktop: WhiteSur by Vince Liuice,\n GPL-3.0, with CybroidOS fixups.\n" "$(echo $REF | tr -d -)+cybroid1" "$REF" > $p/DEBIAN/control
	  printf "#!/bin/sh\nset -e\nif [ \"\$1\" = configure ] && command -v gtk-update-icon-cache >/dev/null; then for t in /usr/share/icons/WhiteSur*; do gtk-update-icon-cache -q -f \"\$t\" || true; done; fi\n" > $p/DEBIAN/postinst
	  chmod 0755 $p/DEBIAN/postinst
	  chown -R root:root $p
	  dpkg-deb --root-owner-group -Zxz --build $p /out/cybroid-icons_all.deb >/dev/null'
	ls -la dist/extra
}

[ "$#" -gt 0 ] || { sed -n 's/^# Usage: //p' "$0" >&2; exit 2; }
for part in "$@"; do
	case "${part}" in
	desktop) corners; apps; tower; dock; icons ;;
	iso) corners; apps; tower; office; dock; icons ;;
	corners | apps | tower | office | dock | icons) "${part}" ;;
	docker) docker_ce ;;
	*) echo "unknown part: ${part}" >&2; exit 2 ;;
	esac
done
